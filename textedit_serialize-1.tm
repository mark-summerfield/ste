# Copyright © 2025-26 Mark Summerfield. All rights reserved.

oo::define TextEdit method serialize {{file_format .ste}} {
    classvariable STE3_PREFIX
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
    # .ste: STE3\n then the fonts line (family and size for each of sans,
    # serif, mono, separated by tabs), then the deflated dump
    set fonts [list]
    foreach kind $FONT_KINDS {
        lappend fonts "[my family_for $kind] [my size_for $kind]"
    }
    set header [encoding convertto utf-8 \
        "$STE3_PREFIX[join $fonts \t]\n"]
    return $header$txt_dumpz
}

oo::define TextEdit method deserialize {raw file_format} {
    if {$file_format ni {.ste .tkt .tktz}} { return 0 }
    if {[catch {my GetTxtDump $raw $file_format} result]} { return 0 }
    classvariable FONT_KINDS
    my clear
    lassign $result txt_dump fonts
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
    # Only v2 and v3 .ste files record fonts (v2 only families); use them
    # so the document looks as it did when saved.
    if {[dict size $fonts]} {
        set current [dict create]
        set wanted [list]
        foreach kind $FONT_KINDS {
            set cur [list [my family_for $kind] [my size_for $kind]]
            dict set current $kind $cur
            lassign [expr {[dict exists $fonts $kind]
                ? [dict get $fonts $kind] : ""}] family size
            if {$family eq ""} { set family [lindex $cur 0] }
            if {$size eq ""} { set size [lindex $cur 1] }
            lappend wanted [list $family $size]
        }
        if {$wanted ne [dict values $current]} {
            my set_fonts {*}$wanted
        }
    }
    my after_load $insert_index
    return 1
}

# Returns {dump fonts} where fonts is a dict (kind -> {family size}),
# empty for v1 and non-.ste formats, and with empty sizes for v2; errors
# on an unknown .ste version.
oo::define TextEdit method GetTxtDump {raw file_format} {
    classvariable FONT_KINDS
    classvariable STE1_PREFIX
    classvariable STE2_PREFIX
    classvariable STE3_PREFIX
    set fonts [dict create]
    if {$file_format eq ".tkt"} {
        return [list [encoding convertfrom utf-8 $raw] $fonts]
    }
    if {$file_format eq ".ste"} {
        set i [string first \n $raw]
        set magic [string range $raw 0 $i]
        if {$magic eq $STE3_PREFIX || $magic eq $STE2_PREFIX} {
            set j [string first \n $raw [incr i]]
            set line [encoding convertfrom utf-8 \
                [string range $raw $i [expr {$j - 1}]]]
            if {$magic eq $STE3_PREFIX} {
                # sans-family size TAB serif-family size TAB mono-...
                # a family may contain spaces so the size is the last word
                foreach kind $FONT_KINDS item [split $line \t] {
                    set k [string last " " $item]
                    set size [string range $item $k+1 end]
                    if {$k < 1 || ![string is integer -strict $size]} {
                        error "invalid .ste fonts"
                    }
                    dict set fonts $kind \
                        [list [string range $item 0 $k-1] $size]
                }
            } else { ;# v2: kind=family TAB kind=family TAB ...
                foreach item [split $line \t] {
                    set k [string first = $item]
                    if {$k > 0} {
                        dict set fonts [string range $item 0 $k-1] \
                            [list [string range $item $k+1 end] ""]
                    }
                }
            }
            set i $j
        } elseif {$magic ne $STE1_PREFIX} {
            error "unrecognized .ste version"
        }
        set raw [string range $raw [incr i] end]
    }
    # elseif $file_format eq ".tktz" then use $raw direct
    list [encoding convertfrom utf-8 [zlib inflate $raw]] $fonts
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
