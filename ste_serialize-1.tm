# Copyright © 2025-26 Mark Summerfield. All rights reserved.

oo::define Ste method serialize {{file_format .ste}} {
    classvariable STE5_PREFIX
    classvariable ALL_FONT_KINDS
    set txt_dump [my StripDerived \
        [$Text dump -text -mark -tag 1.0 "end -1 char"]]
    if {$file_format eq ".tkt"} {
        return $txt_dump
    }
    set txt_dumpz [zlib deflate [encoding convertto utf-8 $txt_dump] 9]
    if {$file_format eq ".tktz"} {
        return $txt_dumpz
    }
    set fonts [list]
    foreach kind $ALL_FONT_KINDS {
        lappend fonts "[my family_for $kind] [my size_for $kind]"
    }
    set fontdata [zlib deflate [encoding convertto utf-8 [join $fonts \t]] \
            9]
    set header "$STE5_PREFIX[string length $fontdata]\n$fontdata"
    return $header$txt_dumpz
}

oo::define Ste method deserialize {raw file_format} {
    if {$file_format ni {.ste .tkt .tktz}} { return 0 }
    try {
        lassign [my GetTxtDumpAndFonts $raw $file_format] txt_dump fontline
    } on error err {
        puts stderr $err
        return 0
    }
    classvariable ALL_FONT_KINDS
    my clear
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
    # Only v2+ .ste files record fonts (v2 only families, v3 no headings);
    # use them so the document looks as it did when saved.
    if {[dict size $fontline]} {
        set current [dict create]
        set wanted [dict create]
        foreach kind $ALL_FONT_KINDS {
            set cur [list [my family_for $kind] [my size_for $kind]]
            dict set current $kind $cur
            lassign [expr {[dict exists $fontline $kind]
                ? [dict get $fontline $kind] : ""}] family size
            if {$family eq ""} { set family [lindex $cur 0] }
            if {$size eq ""} { set size [lindex $cur 1] }
            dict set wanted $kind [list $family $size]
        }
        if {$wanted ne $current} { my set_fonts $wanted }
    }
    my after_load $insert_index
    return 1
}

# Returns {dump fonts} where fonts is a dict (kind -> {family size}),
# empty for v1 and non-.ste formats, with empty sizes for v2, and without
# the headings for v2 and v3; errors on an unknown .ste version.
oo::define Ste method GetTxtDumpAndFonts {raw file_format} {
    classvariable BASE_FONT_KINDS
    classvariable ALL_FONT_KINDS
    classvariable STE1_PREFIX
    classvariable STE2_PREFIX
    classvariable STE3_PREFIX
    classvariable STE4_PREFIX
    classvariable STE5_PREFIX
    set fonts [dict create]
    if {$file_format eq ".tkt"} {
        return [list [encoding convertfrom utf-8 $raw] $fonts]
    }
    if {$file_format eq ".ste"} {
        set i [string first \n $raw]
        set magic [string range $raw 0 $i]
        set j [string first \n $raw [incr i]]
        set line [encoding convertfrom utf-8 [string range $raw $i \
                [expr {$j - 1}]]]
        if {$magic eq $STE5_PREFIX} {
            set i [incr j]
            set j [expr {$i + $line}]
            set fontline [encoding convertto utf-8 [zlib inflate \
                    [string range $raw $i $j]]]
            set fonts [my GetFonts $fontline $ALL_FONT_KINDS]
            set raw [string range $raw $j end]
            return [list [encoding convertfrom utf-8 [zlib inflate $raw]] \
                    $fonts]
        } elseif {$magic in [list $STE4_PREFIX $STE3_PREFIX $STE2_PREFIX]} {
            if {$magic ne $STE2_PREFIX} {
                # v3: sans-family size TAB serif-family size TAB mono-...
                # v4: also h1 h2 h3 h4 in the same format
                # a family may contain spaces so the size is the last word
                set kinds [expr {$magic eq $STE4_PREFIX ? $ALL_FONT_KINDS \
                                                        : $BASE_FONT_KINDS}]
                set fonts [my GetFonts $line $kinds]
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

oo::define Ste method GetFonts {fontline kinds} {
    set items [split $fontline \t]
    if {[llength $items] != [llength $kinds]} { error "invalid .ste fonts" }
    foreach kind $kinds item $items {
        set i [string last " " $item]
        set size [string range $item $i+1 end]
        if {$i < 1 || ![string is integer -strict $size]} {
            error "invalid or missing .ste font size “$size”"
        }
        dict set fonts $kind [list [string range $item 0 $i-1] $size]
    }
    return $fonts
}

# The derived font tags (see refresh_fonts) are rebuilt on load so they
# are never saved.
oo::define Ste method StripDerived dump {
    set result [list]
    foreach {key value index} $dump {
        if {$key in {tagon tagoff} && [string match fnt:* $value]} {
            continue
        }
        lappend result $key $value $index
    }
    return $result
}
