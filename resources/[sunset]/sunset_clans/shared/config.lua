SunsetClans = SunsetClans or {}

SunsetClans.CreationCost = 500
SunsetClans.MaxMembers = 25
SunsetClans.MinTagLength = 2
SunsetClans.MaxTagLength = 6
SunsetClans.MinNameLength = 3
SunsetClans.MaxNameLength = 32
SunsetClans.MaxDescriptionLength = 512
SunsetClans.MaxMotdLength = 512
SunsetClans.InviteExpirySec = 120

SunsetClans.TagStyles = {
    brackets = { label = '[tag]name', order = 1 },
    prefix_dot = { label = 'tag.name', order = 2 },
    suffix_brackets = { label = 'name[tag]', order = 3 },
    suffix_dot = { label = 'name.tag', order = 4 },
    glued_prefix = { label = 'tagname', order = 5 },
    glued_suffix = { label = 'nametag', order = 6 },
}
