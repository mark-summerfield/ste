# Copyright © 2025-26 Mark Summerfield. All rights reserved.

oo::define TextEdit method serialize {{file_format .ste}} {
    classvariable STE2_PREFIX
    classvariable FONT_KINDS
    set txt_dump [my StripDerived \
        [$Text dump -text -mark -tag 1.0 "end -1 char"]]
    if {$file_format eq ".tkt"} {
        return $txt_dump
    }
    set txt_dumpz [zlib deflate [encoding convertto utf-8 $txt_dump] 9]
    if {$file_format eq ".tktz"} {
        return $txt_dumpz
    }
    # .ste: STE2\n then the families line, then the deflated dump
    set families [list]
    foreach kind $FONT_KINDS {
        lappend families $kind=[my family_for $kind]
    }
    set header [encoding convertto utf-8 \
        "$STE2_PREFIX[join $families \t]\n"]
    return $header$txt_dumpz
}

oo::define TextEdit method deserialize {raw file_format} {
    if {$file_format ni {.ste .tkt .tktz}} { return 0 }
    if {[catch {my GetTxtDump $raw $file_format} result]} { return 0 }
    classvariable FONT_KINDS
    my clear
    lassign $result txt_dump families
    array set tags {}
    set insert_index end
    set pending [list]
    foreach {key value index} $txt_dump {
        switch $key {
            text { $Text insert $index $value }
            mark { 
                switch $value {
                    current {}
                    insert { set insert_index $index}
                    default { $Text mark set $value $index }
                }
            }
            tagon {
                set tags($value) $index
                lappend pending $value
            }
            tagoff {
                $Text tag add $value $tags($value) $index
                lpop pending
            }
        }
    }
    while {[llength $pending]} {
        set value [lpop pending]
        $Text tag add $value $tags($value) end
    }
    # Only v2 .ste files record their families; use them so the document
    # looks as it did when saved.
    if {[dict size $families]} {
        set current [dict create]
        foreach kind $FONT_KINDS {
            dict set current $kind [my family_for $kind]
        }
        foreach kind $FONT_KINDS {
            if {![dict exists $families $kind]} {
                dict set families $kind [dict get $current $kind]
            }
        }
        if {$families ne $current} {
            my set_fonts [dict get $families sans] \
                [dict get $families serif] [dict get $families mono] \
                [my font_size]
        }
    }
    my after_load $insert_index
    return 1
}

# Returns {dump families} where families is a dict (kind -> family) that
# is empty for v1 and non-.ste formats; errors on an unknown .ste version.
oo::define TextEdit method GetTxtDump {raw file_format} {
    classvariable STE1_PREFIX
    classvariable STE2_PREFIX
    set families [dict create]
    if {$file_format eq ".tkt"} {
        return [list [encoding convertfrom utf-8 $raw] $families]
    }
    if {$file_format eq ".ste"} {
        set i [string first \n $raw]
        set magic [string range $raw 0 $i]
        if {$magic eq $STE2_PREFIX} {
            set j [string first \n $raw [incr i]]
            set line [encoding convertfrom utf-8 \
                [string range $raw $i [expr {$j - 1}]]]
            foreach item [split $line \t] {
                set k [string first = $item]
                if {$k > 0} {
                    dict set families [string range $item 0 $k-1] \
                        [string range $item $k+1 end]
                }
            }
            set i $j
        } elseif {$magic ne $STE1_PREFIX} {
            error "unrecognized .ste version"
        }
        set raw [string range $raw [incr i] end]
    }
    # elseif $file_format eq ".tktz" then use $raw direct
    list [encoding convertfrom utf-8 [zlib inflate $raw]] $families
}

# The derived font tags (see refresh_fonts) are rebuilt on load so they
# are never saved.
oo::define TextEdit method StripDerived dump {
    set result [list]
    foreach {key value index} $dump {
        if {$key in {tagon tagoff} && [string match fnt:* $value]} {
            continue
        }
        lappend result $key $value $index
    }
    return $result
}
