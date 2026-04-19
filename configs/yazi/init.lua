th.git = th.git or {}
th.git.modified = ui.Style():fg("#3185FC")
th.git.added = ui.Style():fg("#06FFA5")
th.git.untracked = ui.Style():fg("#FFB700")
th.git.deleted = ui.Style():fg("#FF006E"):bold()
th.git.updated = ui.Style():fg("#B14AFF")
th.git.ignored = ui.Style():fg("#4D4D4D")

th.git.modified_sign = "M "
th.git.added_sign = "A "
th.git.untracked_sign = "? "
th.git.deleted_sign = "D "
th.git.updated_sign = "R "
th.git.ignored_sign = "I "

require("full-border"):setup {
	type = ui.Border.PLAIN,
}

require("git"):setup {
	order = 1500,
}
