local include_old = include

include = function(fileName)
    include_old(fileName)

    if fileName == "cl_voice.lua" then
        globals_old = table.Copy(_G)
        registry_old = debug.getregistry()
    end
end