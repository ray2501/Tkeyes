#! /bin/env tclsh

#
# Source code is from https://wiki.tcl.tk/36740
# xeyes clone for Tcl/Tk
#

package require Tk

proc bgerror args {
        puts stderr $::errorInfo
        exit 1
}

proc moreeyes {cx cy} {
        set radius [expr {$::width * rand()/8}]
        set radius [expr {min($radius,$::width/8)}]
        lappend ::eyes [eyes .canvas1 $cx $cy $radius] 
}

namespace eval defaults {
        variable eyes [dict create {*}{
                distfactor 1.1
                pupilfactor .4
                xmove 1
                ymove 1
                wobble .50
                edgefactor .05
        }]
}
proc eyes {canvas cx cy radius args} {
        dict with defaults::eyes {}
        dict with args {}
        set eyes eyes::[clock clicks]
        namespace eval $eyes {}
        set ${eyes}::distfactor $distfactor
        set ${eyes}::pupilfactor $pupilfactor
        set ${eyes}::xmove $xmove
        set ${eyes}::ymove $ymove
        set ${eyes}::radius $radius
        set ${eyes}::edgefactor $edgefactor
        set ${eyes}::wobble $wobble
        namespace upvar $eyes lefteye lefteye righteye righteye
        set lefteye [clock clicks]
        set eyedist [expr {$radius * $distfactor}]
        set ecx [expr {$cx - $eyedist}]
        eye $eyes $canvas $ecx $cy $lefteye
        set righteye [clock clicks]
        set ecx [expr {$cx + $eyedist}]
        eye $eyes $canvas $ecx $cy $righteye
        return $eyes
}

proc eye {eyes canvas x y tag} {
        namespace upvar $eyes radius radius
        namespace upvar $eyes pupilfactor pupilfactor
        namespace upvar $eyes righteye righteye
        $canvas create oval [expr {$x - $radius}] [expr {$y - $radius}] \
                [expr {$x + $radius}] [expr {$y + $radius}] -fill white \
                -tags ${tag}eye

        set pupilradius [expr {$radius * $pupilfactor}]
        set ${eyes}::pupilradius $pupilradius

        $canvas create oval [expr {$x - $pupilradius}] [expr {$y - $pupilradius}] \
                [expr {$x + $pupilradius}] [expr {$y + $pupilradius}] -fill black \
                -tags ${tag}pupil

}

proc distance {xfrom yfrom xto yto} {
        if {$xfrom > $xto} {
                foreach {xfrom xto} [list $xto $xfrom] {}
                set xsign -1
        } else {
                set xsign 1
        }
        if {$yfrom > $yto} {
                foreach {yfrom yto} [list $yto $yfrom] {}
                set ysign -1
        } else {
                set ysign 1
        }
        set xlen [expr {($xto - $xfrom) * $xsign}]
        set ylen [expr {($yto - $yfrom) * $ysign}]
        return [list $xlen $ylen [expr {sqrt($xlen**2 + $ylen**2)}]]
}

proc center {x1 y1 x2 y2} {
        set res [list [expr {$x1 + ($x2 - $x1)/2}] [expr {$y1 + ($y2 - $y1)/2}]]
        return $res
}

proc movement {canvas eyes eye mx my} {
        namespace upvar $eyes radius radius 
        namespace upvar $eyes pupilradius pupilradius
        namespace upvar $eyes wobble wobble
        namespace upvar $eyes xmove myxmove
        namespace upvar $eyes xmove myymove
        namespace upvar $eyes edgefactor edgefactor

        if {$wobble} {
                set xmove [expr {(rand()-0.5)*$wobble}] 
                set ymove [expr {(rand()-0.5)*$wobble}] 
        } else {
                set xmove 0
                set ymove 0
        }

        set eyecenter [center {*}[$canvas coords ${eye}eye]]
        foreach {eyecenterx eyecentery} $eyecenter {}
        set pupilcenter [center {*}[$canvas coords ${eye}pupil]]
        foreach {pupilcenterx pupilcentery} $pupilcenter {}

        foreach {xdist ydist hypotenuse} [distance {*}$eyecenter $mx $my] {
                set base [expr {abs($xdist)}]
                set height [expr {abs($ydist)}]
        }
        set newhypotenuse [expr {$radius - $pupilradius - ($radius * $edgefactor)}]

        if {$hypotenuse <= $newhypotenuse} {        
                set xtarget $mx
                set ytarget $my
        } else {
                #find the target point on $newradius
                if {$base} {
                        set sine [expr {abs(sin(atan(double($height) / $base)))}]
                        set cosine [expr {abs(cos(atan(double($height) / $base)))}]
                        set newheight [expr {$sine * $newhypotenuse}]
                        set newbase [expr {$cosine * $newhypotenuse}]
                } else {
                        set newheight $newhypotenuse
                        set newbase $base 
                }
                if {$mx < $eyecenterx} {
                        set xtarget [expr {$eyecenterx - $newbase}]
                } else {
                        set xtarget [expr {$eyecenterx + $newbase}]
                }
                if {$my < $eyecentery} {
                        set ytarget [expr {$eyecentery - $newheight}]
                } else {
                        set ytarget [expr {$eyecentery + $newheight}]
                }
        }

        if {$pupilcenterx < $xtarget && ($pupilcenterx+1 <= $xtarget)} {
                set xmove $myxmove 
        } elseif {$pupilcenterx > $xtarget && ($pupilcenterx-1 >= $xtarget)} {
                set xmove [expr {-$myxmove}]
        }
        if {$pupilcentery < $ytarget && ($pupilcentery+1 <= $ytarget)} {
                set ymove $myymove
        } elseif {$pupilcentery > $ytarget && ($pupilcentery-1 >=$ytarget)} {
                set ymove [expr {-$myymove}]
        }
        return [list $xmove $ymove]
}

proc moveit {epoch canvas} {
        lassign [winfo pointerxy .] mx my
        set offsetx [winfo rootx $canvas]
        set offsety [winfo rooty $canvas]
        set mx [expr {$mx - $offsetx}]
        set my [expr {$my - $offsety}]
        if {$epoch != $::epoch} {
                return 0
        }
        set again 0
        foreach pair [namespace children eyes] {
                namespace upvar $pair lefteye lefteye righteye righteye 
                foreach eye [list $righteye $lefteye] {
                        foreach {xmove ymove} [movement $canvas $pair $eye $mx $my] {}
                        if {$xmove || $ymove} {
                                $canvas move ${eye}pupil $xmove $ymove
                                set again 1
                        }
                }
        }
        if {$again} {
                after 1 [list moveit $epoch $canvas]
        }
}

variable height 800
variable width 800

# Danilo: Modified here for myself test
wm attributes . -topmost 1
wm resizable . 0 0 

canvas .canvas1 -height $height -width $width -bg black
grid .canvas1

namespace eval eyes {}

eyes .canvas1 [expr {$width / 2}] [expr {$height /2}] [expr {$width * .10}]
bind . <Motion> {moveit [incr ::epoch] .canvas1}
bind .canvas1 <ButtonPress> { moreeyes %x %y }
