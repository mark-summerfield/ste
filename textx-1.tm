# Copyright © 2025 Mark Summerfield. All rights reserved.

# Unique Styles: bold italic bolditalic ColorTags
# Mixable Styles: highlight indent[1-3]

namespace eval textx {}

set textx::ColorTags [dict create \
    black "#000000" \
    apricot "#FFD8B1" \
    beige "#FFFAC8" \
    blue "#4363D8" \
    brown "#9A6324" \
    cyan "#42D4F4" \
    green "#3CB44B" \
    grey "#A9A9A9" \
    lavender "#DCB3FF" \
    lime "#BFEF45" \
    magenta "#F032E6" \
    maroon "#800000" \
    mint "#AAFFC3" \
    navy "#000075" \
    olive "#808000" \
    orange "#F58231" \
    pink "#FABEB4" \
    purple "#911EB4" \
    red "#E6194B" \
    teal "#469990" \
    ]

proc textx::make_fonts {txt_widget family size} {
    foreach name {Sans Bold Italic BoldItalic} {
        catch { font delete $name }
    }
    font create Sans -family $family -size $size
    font create Bold -family $family -size $size -weight bold
    font create Italic -family $family -size $size -slant italic
    font create BoldItalic -family $family -size $size -weight bold \
        -slant italic
    $txt_widget configure -font Sans \
        -foreground [dict get $::textx::ColorTags black]
}

proc textx::make_tags txt_widget {
    $txt_widget tag configure bold -font Bold
    $txt_widget tag configure italic -font Italic
    $txt_widget tag configure bolditalic -font BoldItalic
    $txt_widget tag configure highlight -background "#FFE119" ;# yellow
    dict for {key value} $::textx::ColorTags {
        $txt_widget tag configure $key -foreground $value
    }
    const WIDTH [font measure Sans "•. "]
    set indent [font measure Sans "xxxx"]
    $txt_widget tag configure indent1 -lmargin1 $indent \
        -lmargin2 [expr {$indent + $WIDTH}]
    set indent [expr {$indent * 2}]
    $txt_widget tag configure indent2 -lmargin1 $indent \
        -lmargin2 [expr {$indent + $WIDTH}]
    set indent [expr {$indent * 3}]
    $txt_widget tag configure indent3 -lmargin1 $indent \
        -lmargin2 [expr {$indent + $WIDTH}]
}

proc textx::dump txt_widget {
    $txt_widget dump -text -mark -tag 1.0 "end -1 char"
}

proc textx::undump {txt_widget txt_dump} {
    array set tags {}
    set current_index end
    set insert_index end
    set pending [list]
    foreach {key value index} $txt_dump {
        switch $key {
            text { $txt_widget insert $index $value }
            mark { 
                switch $value {
                    current { set current_index $index }
                    insert { set insert_index $index}
                    default { $txt_widget mark set $value $index }
                }
            }
            tagon {
                set tags($value) $index
                lappend pending $value
            }
            tagoff {
                $txt_widget tag add $value $tags($value) $index
                lpop pending
            }
        }
    }
    while {[llength $pending]} {
        set value [lpop pending]
        $txt_widget tag add $value $tags($value) end
    }
    $txt_widget mark set current $current_index
    $txt_widget mark set insert $insert_index 
}
