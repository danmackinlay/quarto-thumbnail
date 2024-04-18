-- Ensure directory exists or create it
local function ensureDirectoryExists(dir)
    if not os.execute('mkdir -p ' .. pandoc.text.escape_shell_arg(dir)) then
        quarto.log.error("Failed to create directory: " .. dir)
        return false
    end
    return true
end

-- Generate image
function Image(el)
    -- Only process the first image and return immediately after
    if not isFirstImage then return nil end
    isFirstImage = false

    local pathComponents = pandoc.path.split(el.src)
    local filenameWithExt = table.remove(pathComponents)            -- Remove and get the last component as filename
    local dir = table.concat(pathComponents, pandoc.path.separator) -- Reassemble the directory path

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
    if not ensureDirectoryExists(thumbnailDir) then
        return nil
    end

    local thumbnailPath = pandoc.path.join({ thumbnailDir, filename .. ".thumbnail.avif" })

    -- Check if thumbnail is up-to-date
    local srcModTime = getFileModTime(el.src)
    local thumbModTime = getFileModTime(thumbnailPath)
    if thumbModTime and srcModTime and thumbModTime >= srcModTime then
        return nil
    end

    -- Return immediately if vips is not installed
    if not checkIfCommandExists("vips") then
        quarto.log.error("vips is not installed. Please install it to use this filter.")
        return nil
    end

    -- Attempt to create/update the thumbnail
    local command = string.format("vips thumbnail %s %s %d", pandoc.text.escape_shell_arg(el.src),
        pandoc.text.escape_shell_arg(thumbnailPath), 240)
    local result = os.execute(command)
    if result ~= 0 then
        quarto.log.error("Failed to create thumbnail for image " .. el.src)
        return nil
    end

    -- Update image path and metadata
    el.src = thumbnailPath
    quarto.doc.update_metadata({
        image = thumbnailPath
    })

    return el
end
