# Copyright © 2025 Mark Summerfield. All rights reserved.

package require about_form
package require config
package require config_form
package require message_form
package require ui
package require util

oo::class create App {}

oo::define App constructor {} {
    ui::wishinit
    tk appname Styled
    Config new ;# we need tk scaling done early
    my make_ui
}

oo::define App method show {} {
    wm deiconify .
    set config [Config new]
    wm geometry . [$config geometry]
    raise .
    update
}

oo::define App method make_ui {} {
    my prepare_ui
    my make_widgets
    my make_layout
    my make_bindings
}

oo::define App method prepare_ui {} {
    wm title . [tk appname]
    wm iconname . [tk appname]
    wm iconphoto . -default [ui::icon icon.svg]
}

oo::define App method make_widgets {} {
    set config [Config new]
}

oo::define App method make_layout {} {
    const opts "-pady 3 -padx 3"
}

oo::define App method make_bindings {} {
    wm protocol . WM_DELETE_WINDOW [callback on_quit]
}

oo::define App method on_config {} { ConfigForm new }

oo::define App method on_about {} {
    AboutForm new "A Styled Text Editor" \
        https://github.com/mark-summerfield/styled
}

oo::define App method on_quit {} {
    set config [Config new]
    $config save
    exit
}

