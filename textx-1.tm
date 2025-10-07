# Copyright © 2025 Mark Summerfield. All rights reserved.

# Unique Styles: bold italic bolditalic COLOR_TAGS
# Mixable Styles: highlight indent[1-3]

package require html 1

namespace eval textx {}

const textx::HIGHLIGHT "#FFE119"

const textx::COLOR_TAGS [dict create \
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
        -foreground [dict get $::textx::COLOR_TAGS black]
}

proc textx::make_tags txt_widget {
    $txt_widget tag configure bold -font Bold
    $txt_widget tag configure italic -font Italic
    $txt_widget tag configure bolditalic -font BoldItalic
    $txt_widget tag configure highlight -background $::textx::HIGHLIGHT
    dict for {key value} $::textx::COLOR_TAGS {
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

proc textx::serialize txt_widget {
    set txt_dump [$txt_widget dump -text -mark -tag 1.0 "end -1 char"]
    zlib deflate [encoding convertto utf-8 $txt_dump] 9
}

proc textx::deserialize {txt_widget txt_dumpz} {
    set txt_dump [encoding convertfrom utf-8 [zlib inflate $txt_dumpz]]
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

proc textx::html {txt_widget filename} {
    set txt_dump [$txt_widget dump -text -mark -tag 1.0 "end -1 char"]
    set title [html::html_entities [file rootname [file tail $filename]]]
    set out [list "<html>\n<head><title>$title</title></head>\n<body>"]
    set pending [list]
    foreach {key value _} $txt_dump {
        switch $key {
            text {
                set value [regsub -all \n\n $value <p>]
                set value [regsub -all \n $value " "]
                lappend out [html::html_entities $value]
            }
            tagon {
                lappend out [html_on $value]
                lappend pending $value
            }
            tagoff {
                lappend out [html_off $value]
                lpop pending
            }
        }
    }
    while {[llength $pending]} {
        set value [lpop pending]
        lappend out [html_off $value]
    }
    lappend out "</body>\n</html>\n"
    join $out \n
}

proc textx::html_on tag {
    switch $tag {
        bold { return <b> }
        italic { return <i> }
        bolditalic { return <b><i> }
        highlight { return "<span style=\"background-color:\
            $::textx::HIGHLIGHT;\">" }
        indent1 { return "<div style=\"text-indent: 2em;\">" }
        indent2 { return "<div style=\"text-indent: 4em;\">" }
        indent3 { return "<div style=\"text-indent: 6em;\">" }
        default {
            return "<span style=\"color: \
                [dict get $::textx::COLOR_TAGS $tag];\">"
        }
    }
}

proc textx::html_off tag {
    switch $tag {
        bold { return </b> }
        italic { return </i> }
        bolditalic { return </i></b> }
        highlight { return </span> }
        indent1 { return </div> }
        indent2 { return </div> }
        indent3 { return </div> }
        default { return </span> }
    }
}
