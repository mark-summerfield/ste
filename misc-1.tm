# Copyright © 2025 Mark Summerfield. All rights reserved.

namespace eval misc {}

proc misc::swatch {color size} {
    const R [expr {max(3, $size / 4.0)}]
    const W [expr {$R + 2.5}]
    const SVG_TXT "<svg width=\"$size\" height=\"$size\">
        <rect x=\"0\" y=\"0\" width=\"$size\" height=\"$size\"
            rx=\"$R\" ry=\"$R\" fill=\"$color\"
            stroke-width=\"$W\" stroke=\"white\">
        </svg>"
    image create photo -data $SVG_TXT
}
