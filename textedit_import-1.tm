# Copyright © 2025 Mark Summerfield. All rights reserved.

package require htmlparse 1

oo::define TextEdit method import_text txt {
    my clear
    $Text insert end $txt
    my after_load 1.0
}

oo::define TextEdit method import_html html {
    set html [regsub -all {<b><i>|<i><b>} $html <bi>]
    set html [regsub -all {</b></i>|</i></b>} $html </bi>]
    my clear
    htmlparse::parse -cmd [callback HandleHtmlTag] $html
    my after_load 1.0
}

# TODO:
# bi
# for li use bindent1
# strike sub sup u center right + fix bold & italic → bolditalic
oo::define TextEdit method HandleHtmlTag {tag slash param txt} {
    classvariable COLOR_FOR_TAG
    classvariable TAG_FOR_HTML_COLOR
    const COLOR_TAGS [dict keys $COLOR_FOR_TAG]
    set txt [string trimright [htmlparse::mapEscapes $txt] \n]
    set bold_index ""
    set color_index ""
    set color_tag ""
    set italic_index ""
    set highlight_index ""
    if {$slash eq ""} {
        switch $tag {
            b {
                if {$txt ne ""} { $Text insert end $txt bold }
                set bold_index [$Text index end]
            }
            br {
                $Text insert end [expr {[string trim $txt] eq ""\
                                             ? " " : $txt}]
            }
            i {
                if {$txt ne ""} { $Text insert end $txt italic }
                set italic [$Text index end]
            }
            p { if {$txt ne ""} { $Text insert end $txt } }
            li { $Text insert end "• $txt" }
            span {
                if {[regexp {background-color:\s*yellow} $param]} {
                    if {$txt ne ""} { $Text insert end $txt highlight }
                    set highlight_index [$Text index end]
                } else {
                    regexp {color:\s*(#[A-Fa-f0-9]+)} $param _ color
                    if {[info exists color]} {
                        set color_tag [dict getdef $TAG_FOR_HTML_COLOR \
                                        [string toupper $color] \
                                        [lrandom $COLOR_TAGS]]
                        if {$color_tag ne ""} {
                            if {$txt ne ""} {
                                $Text insert end $txt $color_tag
                                set txt ""
                            }
                            set color_index [$Text index end]
                        }
                    }
                    if {$txt ne ""} { $Text insert end $txt }
                }
            }
            hmstart - html - head - title - body - meta - ul - ol - style {}
            default {
                puts "skipped <$tag $param>" ;# TODO debug
            }
        }
    } else {
        switch $tag {
            b {
                if {$bold_index ne ""} {
                    $Text tag add bold $bold_index end
                    set bold_index ""
                }
                if {$txt ne ""} { $Text insert end $txt }
            }
            br {
                $Text insert end [expr {[string trim $txt] eq ""\
                                             ? " " : $txt}]
            }
            i {
                if {$italic_index ne ""} {
                    $Text tag add italic $italic_index end
                    set italic_index ""
                }
                if {$txt ne ""} { $Text insert end $txt }
            }
            li - p { $Text insert end $txt\n }
            span {
                if {$highlight_index ne ""} {
                    $Text tag add yellow $highlight_index end
                    set highlight_index ""
                }
                if {$color_index ne "" && $color_tag ne ""} {
                    $Text tag add $color_tag $color_index end
                    set color_index ""
                }
                if {$txt ne ""} { $Text insert end $txt }
            }
            hmstart - html - head - title - body - meta - ul - ol - style {}
            default {}
        }
    }
}
