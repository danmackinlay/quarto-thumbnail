-- Global variables to manage image processing
local firstThumbnailPath = nil -- Store the first valid thumbnail path
local seenImagePaths = {}      -- Keep track of image paths we've processed

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
    if not handle then
        return nil
    end
    local result = handle:read("*a")
    handle:close()
    local modTime = tonumber(result)
    return modTime
end

function Image(el)
    -- Quit early if the first thumbnail has already been processed or if image is marked as seen
    if firstThumbnailPath or seenImagePaths[el.src] then return nil end

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
        seenImagePaths[el.src] = true
        return nil -- Use existing thumbnail
    end
    if not checkIfCommandExists("vips") then
        quarto.log.error("vips is not installed. Please install it to use this filter.")
        return nil
    end

    local command = string.format("vips thumbnail %s %s %d", escapeShellArg(el.src), escapeShellArg(thumbnailPath), 240)
    local handle = io.popen(command .. " 2>&1", "r")
    local output = handle and handle:read("*all")
    if handle then
        handle:close()
    end
    if output and output ~= "" then
        quarto.log.error("Failed to create thumbnail for image " .. el.src .. " with error: " .. output)
        return nil
    end

    seenImagePaths[el.src] = true
    firstThumbnailPath = thumbnailPath -- Store the first valid thumbnail path
    return el
end

function Figure(fig)
    -- Check if the figure has 'foreign' class; if so, do not process any images within it
    if fig.attr.classes:includes('foreign') then
        for _, content in pairs(fig.content) do
            if content.t == 'Image' then
                seenImagePaths[content.src] = true -- Mark as seen to skip processing
            end
        end
        return fig
    end

    -- Process images within the figure if not 'foreign'
    for _, content in pairs(fig.content) do
        if content.t == 'Image' then
            Image(content)
        end
    end
    return fig
end

function Meta(meta)
    if firstThumbnailPath then
        meta['image'] = firstThumbnailPath -- Update metadata with the first valid image's thumbnail path
    end
    return meta
end

return {
    { Image = Image, Figure = Figure }, -- Process Images and Figures
    { Meta = Meta }                     -- Update metadata last
}
