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
    -- Return early if image is excluded or a thumbnail has already been set
    if seenImagePaths[el.src] or firstThumbnailPath then return nil end
    -- if the image is foreign, we don't want to process it
    if el.attr.classes:includes('foreign') then return nil end
    -- this doesn't need any js; but there isn't a point with using this with epubs
    if not quarto.doc.is_format("html:js") then return nil end

    local relsrc = el.src
    -- if absolute we want to resolve relative to project root,
    -- which is maybe where it is executed?
    local projectRoot = quarto.project.directory
    -- quarto.log.output({ 'projectRoot', projectRoot })
    local workingDir = pandoc.system.get_working_directory()
    -- quarto.log.output({ 'workingDir', workingDir })
    if pandoc.path.is_absolute(relsrc) then
        -- relsrc = pandoc.path.normalize(relsrc)
        sourcePath_seg = pandoc.path.split(relsrc)
        -- delete the leading absolut path element
        table.remove(sourcePath_seg, 1)
        relsrc = pandoc.path.join(sourcePath_seg)
        -- quarto.log.output({ 'sourcepath1', relsrc })
        if projectRoot then
            relsrc = pandoc.path.join({ projectRoot, relsrc })
        end
        -- quarto.log.output({ 'sourcepath2', relsrc })
    else
        relsrc = pandoc.path.make_relative(workingDir, relsrc, false)
    end

    local pathComponents = pandoc.path.split(relsrc)
    local filenameWithExt = table.remove(pathComponents)
    local dir = pandoc.path.join(pathComponents)

    local filename, extension = pandoc.path.split_extension(filenameWithExt)
    if not filename then
        quarto.log.error("Failed to extract filename from path: " .. filenameWithExt)
        return nil
    end
    local thumbnailDir = pandoc.path.join({ dir, "thumbnail" })

    if not ensureDirectoryExists(thumbnailDir) then return nil end

    local thumbnailPath = pandoc.path.join({ thumbnailDir, filename .. ".thumbnail.avif" })
    -- quarto.log.output({ 'thumbnailPath', thumbnailPath })

    local srcModTime = getFileModTime(relsrc)
    local thumbModTime = getFileModTime(thumbnailPath)

    if thumbModTime and srcModTime and thumbModTime >= srcModTime then
        seenImagePaths[relsrc] = true
        return nil -- Use existing thumbnail
    end
    if not checkIfCommandExists("vips") then
        quarto.log.error("vips is not installed. Please install it to use this filter.")
        return nil
    end

    local command = string.format("vips thumbnail %s %s %d", escapeShellArg(relsrc), escapeShellArg(thumbnailPath), 240)
    local handle = io.popen(command .. " 2>&1", "r")
    local output = handle and handle:read("*all")
    if handle then
        handle:close()
    end
    if output and output ~= "" then
        quarto.log.error("Failed to create thumbnail for image " .. relsrc .. " with error: " .. output)
        return nil
    end
    seenImagePaths[el.src] = true
    firstThumbnailPath = thumbnailPath -- Store the first valid thumbnail path
    return el
end

function Figure(fig)
    -- if the figure is foreign, we don't want to process it or its children
    if fig.attr.classes:includes('foreign') then
        pandoc.walk_block(fig, {
            Image = function(el)
                seenImagePaths[el.src] = true -- Mark this image as processed
            end
        })
    end
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
