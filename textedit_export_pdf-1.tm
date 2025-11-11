# Copyright © 2025 Mark Summerfield. All rights reserved.

oo::define TextEdit method to_pdf filename {
    set pdf [pdf4tcl::new %AUTO% -paper a4 -margin 20mm]
    try {
        $pdf startPage
        $pdf metadata -creator TextEdit
        $pdf setFont 11 Helvetica

        lassign [my GetTagDicts] tags_on tags_off
        foreach para [lseq 1 to [$Text count -lines 1.0 end]] {
            set line ""
            set nchars [$Text count -chars $para.0 $para.end]
            foreach char [lseq 0 to $nchars] {
                set index $para.$char
                set tag_on [dict getdef $tags_on $index ""]
                set tag_off [dict getdef $tags_off $index ""]
                if {[set c [$Text get $index]] eq "\n"} {
                    set c " "
                }
                if {$tag_off ne ""} {
                    foreach tag [$tag_off tags] {
                        #lappend line [my HtmlTagOff $tag]
                    }
                }
                if {$tag_on ne ""} {
                    foreach tag [$tag_on tags] {
                        #lappend line [my HtmlTagOn prefix $tag]
                    }
                }
                if {$c ne ""} { lappend line $c }
            }
            if {[set line [string trim [join $line ""]]] ne ""} {
                #lappend out "$prefix\n$line\n</p>\n"
            }
        }

        $pdf write -file $filename
    } finally {
        $pdf destroy
    }
}
