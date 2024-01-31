local ll = require('lualine')

ll.setup{
    options = {theme = 'material'},
    sections = {
        lualine_x = {'filesize', 'encoding', 'fileformat', 'filetype'},
        lualine_y = {'progress'},
        lualine_z = {'location'}
    }
}
