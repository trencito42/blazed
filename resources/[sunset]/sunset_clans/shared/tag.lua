SunsetClans = SunsetClans or {}

function SunsetClans.isValidTagStyle(style)
    return type(style) == 'string' and SunsetClans.TagStyles[style] ~= nil
end

function SunsetClans.formatTaggedName(tag, baseName, style)
    tag = tostring(tag or '')
    baseName = tostring(baseName or '')
    if tag == '' then return baseName end
    style = SunsetClans.isValidTagStyle(style) and style or 'brackets'
    if style == 'brackets' then
        return ('[%s]%s'):format(tag, baseName)
    elseif style == 'prefix_dot' then
        return ('%s.%s'):format(tag, baseName)
    elseif style == 'suffix_brackets' then
        return ('%s[%s]'):format(baseName, tag)
    elseif style == 'suffix_dot' then
        return ('%s.%s'):format(baseName, tag)
    elseif style == 'glued_prefix' then
        return tag .. baseName
    elseif style == 'glued_suffix' then
        return baseName .. tag
    end
    return baseName
end

function SunsetClans.splitTaggedParts(tag, baseName, style)
    tag = tostring(tag or '')
    baseName = tostring(baseName or '')
    if tag == '' then
        return { prefix = '', name = baseName, suffix = '' }
    end
    style = SunsetClans.isValidTagStyle(style) and style or 'brackets'
    if style == 'brackets' then
        return { prefix = ('[%s]'):format(tag), name = baseName, suffix = '' }
    elseif style == 'prefix_dot' then
        return { prefix = tag .. '.', name = baseName, suffix = '' }
    elseif style == 'suffix_brackets' then
        return { prefix = '', name = baseName, suffix = ('[%s]'):format(tag) }
    elseif style == 'suffix_dot' then
        return { prefix = '', name = baseName, suffix = '.' .. tag }
    elseif style == 'glued_prefix' then
        return { prefix = tag, name = baseName, suffix = '' }
    elseif style == 'glued_suffix' then
        return { prefix = '', name = baseName, suffix = tag }
    end
    return { prefix = '', name = baseName, suffix = '' }
end
