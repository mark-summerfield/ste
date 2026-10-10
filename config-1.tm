# Copyright © 2025-26 Mark Summerfield. All rights reserved.

package require inifile
package require util

# Also handles tk scaling
oo::singleton create Config {
    variable Filename
    variable Blinking
    variable Geometry
    variable Families ;# dict of kind (sans serif mono) -> family
    variable FontSize
    variable LastFile
    variable ShowIndents
    variable HiddenToolbars
}

oo::define Config constructor {} {
    set Filename [util::get_ini_filename]
    set Blinking 1
    set Geometry ""
    set Families [list sans [font configure TkDefaultFont -family] \
            serif Times mono [font configure TkFixedFont -family]]
    set FontSize [expr {1 + [font configure TkDefaultFont -size]}]
    set LastFile ""
    set ShowIndents 0
    set HiddenToolbars [list]
    if {[file exists $Filename] && [file size $Filename]} {
        set ini [ini::open $Filename -encoding utf-8 r]
        try {
            tk scaling [ini::value $ini General Scale [tk scaling]]
            if {![set Blinking [ini::value $ini General Blinking \
                    $Blinking]]} {
                option add *insertOffTime 0
                ttk::style configure . -insertofftime 0
            }
            set Geometry [ini::value $ini General Geometry $Geometry]
            # FontFamily was the only family in earlier versions
            dict set Families sans [ini::value $ini General SansFamily \
                    [ini::value $ini General FontFamily \
                        [dict get $Families sans]]]
            dict set Families serif [ini::value $ini General \
                    SerifFamily [dict get $Families serif]]
            dict set Families mono [ini::value $ini General MonoFamily \
                    [dict get $Families mono]]
            set FontSize [ini::value $ini General FontSize $FontSize]
            set LastFile [ini::value $ini General LastFile $LastFile]
            set ShowIndents [ini::value $ini General ShowIndents \
                $ShowIndents]
            set HiddenToolbars [split [ini::value $ini General \
                    HiddenToolbars [join $HiddenToolbars]] " "]
        } on error err {
            puts "invalid config in '$Filename'; using defaults: $err"
        } finally {
            ini::close $ini
        }
    }
}

oo::define Config method save filename {
    set ini [ini::open $Filename -encoding utf-8 w]
    try {
        ini::set $ini General Scale [tk scaling]
        ini::set $ini General Blinking [my blinking]
        ini::set $ini General Geometry [wm geometry .]
        ini::set $ini General SansFamily [my family sans]
        ini::set $ini General SerifFamily [my family serif]
        ini::set $ini General MonoFamily [my family mono]
        ini::set $ini General FontSize [my size]
        ini::set $ini General LastFile $filename
        ini::set $ini General ShowIndents [my show_indents]
        ini::set $ini General HiddenToolbars [join $HiddenToolbars]
        ini::commit $ini
    } finally {
        ini::close $ini
    }
}

oo::define Config method filename {} { set Filename }
oo::define Config method set_filename filename { set Filename $filename }

oo::define Config method blinking {} { set Blinking }
oo::define Config method set_blinking blinking { set Blinking $blinking }

oo::define Config method geometry {} { set Geometry }
oo::define Config method set_geometry geometry { set Geometry $geometry }

oo::define Config method size {} { set FontSize }
oo::define Config method set_size size { set FontSize $size }

oo::define Config method family kind { dict get $Families $kind }
oo::define Config method set_family {kind family} {
    dict set Families $kind $family
}

oo::define Config method lastfile {} { set LastFile }
oo::define Config method set_lastfile lastfile { set LastFile $lastfile }

oo::define Config method show_indents {} { set ShowIndents }
oo::define Config method set_show_indents show_indents {
    set ShowIndents $show_indents
}

oo::define Config method hidden_toolbars {} { set HiddenToolbars }
oo::define Config method set_hidden_toolbars toolbars {
    set HiddenToolbars $toolbars ;# toolbars must be a list
}

oo::define Config method to_string {} {
    return "Config filename=$Filename blinking=$Blinking\
        scaling=[tk scaling] geometry=$Geometry families=[list $Families]\
        fontsize=$FontSize lastfile=$LastFile show_indents=$ShowIndents\
        hidden_toolbars=$HiddenToolbars"
}
