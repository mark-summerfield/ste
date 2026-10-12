# Copyright © 2025-26 Mark Summerfield. All rights reserved.

package require inifile
package require util

# Also handles tk scaling
oo::singleton create Config {
    variable Filename
    variable Blinking
    variable Geometry
    variable Fonts ;# dict of kind (sans serif mono) -> {family size}
    variable LastFile
    variable ShowIndents
    variable HiddenToolbars
}

oo::define Config constructor {} {
    set Filename [util::get_ini_filename]
    set Blinking 1
    set Geometry ""
    set size [expr {1 + [font configure TkDefaultFont -size]}]
    set Fonts [list \
        sans [list [font configure TkDefaultFont -family] $size] \
        serif [list Times $size] \
        mono [list [font configure TkFixedFont -family] $size]]
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
            # FontFamily and FontSize were the only font settings in
            # earlier versions
            set legacy_size [ini::value $ini General FontSize $size]
            foreach kind {sans serif mono} {
                set Kind [string totitle $kind]
                set family [lindex [dict get $Fonts $kind] 0]
                if {$kind eq "sans"} {
                    set family [ini::value $ini General FontFamily \
                        $family]
                }
                dict set Fonts $kind [list \
                    [ini::value $ini General ${Kind}Family $family] \
                    [ini::value $ini General ${Kind}Size $legacy_size]]
            }
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
        foreach kind {sans serif mono} {
            set Kind [string totitle $kind]
            ini::set $ini General ${Kind}Family [my family $kind]
            ini::set $ini General ${Kind}Size [my size $kind]
        }
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

oo::define Config method font kind { dict get $Fonts $kind }
oo::define Config method family kind { lindex [dict get $Fonts $kind] 0 }
oo::define Config method size kind { lindex [dict get $Fonts $kind] 1 }
oo::define Config method set_font {kind family size} {
    dict set Fonts $kind [list $family $size]
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
        scaling=[tk scaling] geometry=$Geometry fonts=[list $Fonts]\
        lastfile=$LastFile show_indents=$ShowIndents\
        hidden_toolbars=$HiddenToolbars"
}
