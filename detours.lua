local include_old = include

include = function(fileName)
    include_old(fileName)

    if fileName == "cl_voice.lua" then
        _G.globals_old = table.Copy(_G)
        _G.registry_old = debug.getregistry()
    end
end
