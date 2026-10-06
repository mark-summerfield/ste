# Copyright © 2025-26 Mark Summerfield. All rights reserved.

package require globals
package require ui

oo::singleton create App {
    variable Filename
    variable Toolbars
    variable ATextEdit
    variable FindEntry
    variable FindIndex
    variable ShowFindPanel
    variable StatusLabel
}

package require app_actions
package require app_make
package require app_support

oo::define App constructor {} {
    ui::wishinit
    tk appname $::APPNAME
    set config [Config new]
    set Toolbars {}
    set FindIndex 1.0
    set ShowFindPanel 0
    set Filename [expr {$::argc ? [lindex $::argv 0] : ""}]
    if {$Filename eq ""} { set Filename [$config lastfile] }
    my make_ui
}

oo::define App method show {} {
    wm deiconify .
    set config [Config new]
    wm geometry . [$config geometry]
    raise .
    update
    after idle [callback on_startup]
}

oo::define App method on_startup {} {
    set config [Config new]
    $Toolbars hide_toolbars {*}[$config hidden_toolbars]
    update
    if {$Filename ne "" && [file isfile $Filename]} {
        my file_open
    } else {
        $ATextEdit clear
        $ATextEdit mark set insert end
        $ATextEdit see insert
        $ATextEdit focus
    }
}

oo::define App method show_message {msg {timeout short}} {
    $StatusLabel configure -text $msg -foreground navy
    set timeout [expr {$timeout eq "short" ? $::SHORT_TIMEOUT \
                                           : $::LONG_TIMEOUT}]
    after $timeout [callback clear_status]
}

oo::define App method show_error err {
    $StatusLabel configure -text $err -foreground red
    after $::LONG_TIMEOUT [callback clear_status]
}

oo::define App method clear_status {} { $StatusLabel configure -text "" }
