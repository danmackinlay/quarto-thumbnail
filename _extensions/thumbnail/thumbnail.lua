-- Function to safely escape shell arguments
local function escapeShellArg(arg)
    if not arg then return '' end
    return "'" .. arg:gsub("'", "'\\''") .. "'"
end

local function checkIfCommandExists(command)
    local checked = os.execute("command -v " .. command .. " &> /dev/null")
    return checked ~= nil
end

-- Ensure directory exists or create it
local function ensureDirectoryExists(dir)
    if not os.execute('mkdir -p ' .. escapeShellArg(dir)) then
        quarto.log.error("Failed to create directory: " .. dir)
        return false
    end
    return true
end

local function getFileModTime(path)
    local command = "stat -c %Y " .. escapeShellArg(path) .. " 2> /dev/null"
    local handle = io.popen(command)
    local result = handle:read("*a")
    handle:close()
    return tonumber(result)
end

local firstThumbnailPath -- Store the first thumbnail path

function Image(el)
    -- Quit early if the first thumbnail has already been processed
    if firstThumbnailPath then return nil end

    local pathComponents = pandoc.path.split(el.src)
    local filenameWithExt = table.remove(pathComponents)
    local dir = table.concat(pathComponents, pandoc.path.separator)
    if not dir or dir == "" then
        quarto.log.error("Directory path is empty or invalid.")
        return nil
    end

    local filename, extension = pandoc.path.split_extension(filenameWithExt)
    if not filename then
        quarto.log.error("Failed to extract filename from path: " .. filenameWithExt)
        return nil
    end

    local thumbnailDir = pandoc.path.join({ dir, "thumbnail" })
    if not ensureDirectoryExists(thumbnailDir) then return nil end

    local thumbnailPath = pandoc.path.join({ thumbnailDir, filename .. ".thumbnail.avif" })
    local srcModTime = getFileModTime(el.src)
    local thumbModTime = getFileModTime(thumbnailPath)

    if thumbModTime and srcModTime and thumbModTime >= srcModTime then
        firstThumbnailPath = thumbnailPath
        return nil
    end
    if not checkIfCommandExists("vips") then
        quarto.log.error("vips is not installed. Please install it to use this filter.")
        return nil
    end

    local command = string.format("vips thumbnail %s %s %d", escapeShellArg(el.src), escapeShellArg(thumbnailPath),
        240)
    local handle = io.popen(command .. " 2>&1", "r")
    local output = handle and handle:read("*all")
    handle:close()
    if output and output ~= "" then
        quarto.log.error("Failed to create thumbnail for image " .. el.src .. " with error: " .. output)
        return nil
    end

    firstThumbnailPath = thumbnailPath -- Store the first thumbnail path
    return el
end

function Meta(meta)
    if firstThumbnailPath then
        meta['image'] = firstThumbnailPath -- Update metadata with the first image's thumbnail path
    end
    return meta
end

return {
    { Image = Image }, -- (1)
    { Meta = Meta }  -- (2)
}
