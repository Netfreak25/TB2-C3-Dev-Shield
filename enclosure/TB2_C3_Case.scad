/* TB2 C3 Dev Shield flat dock, Rev. 0.3. Units: mm.
 * Construction coordinates follow the PCB drawing: USB edge y=0, +Y down.
 * Outputs convert once to Cartesian +Y up; PCB lower face stays at pcb_z.
 * Hardware envelopes and physical fit remain unverified.
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

/* [Output] */
part = "assembly"; // [assembly,exploded,section,base,lid,layout,led_membrane_probe,collision_case,collision_hardware,collision_fasteners,collision_usb,collision_cable,collision_lid_path,collision_module_path]
show_hardware = true;
show_labels = true;
explode = 14;

/* [Print fit] */
wall = 1.8;
floor_t = 1.6;
roof_t = 1.6;
fit = 0.25;
pcb_xy_clearance = 0.3;
pcb_hold_gap = 0.2;
solder_clearance = 3.0;
print_layer_h = 0.2;

/* [MAGIC lettering] */
mark_depth = 0.6;
letter_h = 4.4;
letter_w = 3.2;
stroke_w = 0.9;
letter_gap = 0.6;
star_w = 2.8;
star_h = 3.2;
star_tip = 0.8;

/* [ESP32 stack - measure your module] */
socket_h = 8.5;
male_spacer_h = 2.5;
module_pcb_t = 1.6;
usb_shell_h = 3.2;
usb_plug_w = 14;
usb_plug_h = 7;

/* [M2 hardware] */
insert_bore_d = 3.2;
insert_length = 3;
insert_recess = 0.2;
screw_length = 8;
screw_hole_d = 2.3;
screw_head_d = 3.8;
screw_head_h = 2;
clamp_depth = 3.6;
tip_clearance = 0.8;

/* [Hidden] */
$fn = 48;
eps = 0.01;
pcb_w = 39;
pcb_d = 22.52;
pcb_t = 1.6;
pcb_z = floor_t + solder_clearance;
pcb_top = pcb_z + pcb_t;
module_x = 2.6;
module_w = 18;
module_center = module_x + module_w/2;
module_z = pcb_top + socket_h + male_spacer_h;
module_top = module_z + module_pcb_t;
usb_center_z = module_top + usb_shell_h/2;
case_top = pcb_top + 6.6;
seam_z = case_top - roof_t;
case_min = [-7,-4];
case_size = [53,pcb_d+8];
corner_r = 3;
skirt_drop = 1.4;
skirt_t = 1.0;
skirt_inset = wall+fit;
screw_axes = [[-3.5,pcb_d/2],[42.5,pcb_d/2]];
boss_d = 6.8;
lid_pad_d = 5.2;
boss_top = case_top-clamp_depth;
insert_top = boss_top-insert_recess;
insert_bottom = insert_top-insert_length;
screw_tip = case_top-screw_length;
tip_floor = screw_tip-tip_clearance;
support_ys = [2.5,18.0];
support_depth = 2;
pcb_bearing = 0.4;
module_open_min = [2.15,-0.5];
module_open_max = [21.05,23.02];
service_open_min = [23.5,-0.2];
service_open_max = [34.2,22.9];
led_center = [36,20.75];
led_aperture_d = 4.2;
led_membrane_t = print_layer_h;
word_w = 4*letter_w+stroke_w+4*letter_gap;
white = [0.94,0.95,0.94];

assert(tip_floor>floor_t, "Screw tip relief would breach the floor");
assert(insert_bottom>screw_tip, "Screws must reach the full insert thread");
assert(boss_top>pcb_top && boss_top<seam_z, "Invalid boss / lid bearing heights");
assert(module_z>case_top, "This dock requires socket-mounted ESP32 hardware");
assert(service_open_min.x-module_open_max.x>=2*skirt_t, "Aperture bridge too narrow");
assert(pcb_bearing<0.54, "Left support would overlap an outer ESP32 pad");
assert(led_membrane_t>0 && led_membrane_t<roof_t, "Invalid single-layer LED skin");
assert(mark_depth<wall && (case_top+letter_h)/2<seam_z,
       "Lettering must leave a wall backing and stay below the lid seam");

module box(a,b) { translate(a) cube(b-a); }
module pcb_to_world() {
    // Preserve PCB top-view handedness: USB above, ESP32 left, connector right.
    translate([0,pcb_d,0]) mirror([0,1,0]) children();
}
module outline(inset=0) {
    offset(r=corner_r-inset)
        translate(case_min+[corner_r,corner_r])
            square(case_size-[2*corner_r,2*corner_r]);
}
module slab(z0,z1,inset=0) {
    translate([0,0,z0]) linear_extrude(z1-z0) outline(inset);
}
module axis(i) { translate([screw_axes[i].x,screw_axes[i].y,0]) children(); }
module cylinder_z(d,z0,z1) { translate([0,0,z0]) cylinder(d=d,h=z1-z0); }
module aperture(a,b) { box([a.x,a.y,0],[b.x,b.y,case_top+eps]); }
module openings() {
    aperture(module_open_min,module_open_max);
    aperture(service_open_min,service_open_max);
    // Blind pocket from underneath: the outer face stays completely closed.
    translate([led_center.x,led_center.y,0])
        cylinder(d=led_aperture_d,h=case_top-led_membrane_t);
}
module perimeter_shell(z0,z1) {
    difference() { slab(z0,z1); slab(z0-eps,z1+eps,wall); }
}
module pcb_seats() {
    // Bear only on the PCB's unpopulated outer edges, avoiding all pads.
    for(y=support_ys) {
        box([-5.2,y,floor_t-eps],[pcb_bearing,y+support_depth,pcb_z]);
        box([pcb_w-pcb_bearing,y,floor_t-eps],[44.2,y+support_depth,pcb_z]);
        box([-0.6,y,pcb_z-eps],[-pcb_xy_clearance,y+support_depth,pcb_top+0.1]);
        box([pcb_w+pcb_xy_clearance,y,pcb_z-eps],[pcb_w+0.6,y+support_depth,pcb_top+0.1]);
    }
    for(y=[-0.6,pcb_d+pcb_xy_clearance])
        box([9,y,floor_t-eps],[13,y+0.3,pcb_top+0.1]);
}
module insert_bores() {
    for(i=[0:1]) axis(i) {
        cylinder_z(screw_hole_d,tip_floor,boss_top+eps);
        cylinder_z(insert_bore_d,insert_bottom-0.4,boss_top+eps);
        translate([0,0,boss_top-0.35])
            cylinder(d1=insert_bore_d,d2=insert_bore_d+0.6,h=0.35+eps);
    }
}
module letter_line(points) {
    for(i=[0:len(points)-2]) hull() {
        translate(points[i]) square(stroke_w,center=true);
        translate(points[i+1]) square(stroke_w,center=true);
    }
}
module magic_word() {
    // Geometric lettering from the original MAGIC enclosure; no system font.
    w=letter_w; h=letter_h; r=stroke_w/2; c=0.8;
    letter_line([[r,r],[r,h-r],[w/2,h*0.53],[w-r,h-r],[w-r,r]]);
    translate([w+letter_gap,0]) difference() {
        polygon([[0,0],[0,h-c],[c,h],[w-c,h],[w,h-c],[w,0]]);
        translate([stroke_w,-eps]) square([w-2*stroke_w,0.96]);
        translate([stroke_w,0.95+stroke_w]) square([w-2*stroke_w,h-0.95-2*stroke_w]);
    }
    translate([2*(w+letter_gap),0])
        letter_line([[w-r,h-c],[w-c,h-r],[c,h-r],[r,h-c],[r,c],
                     [c,r],[w-c,r],[w-r,c],[w-r,h*0.4],[w*0.65,h*0.4]]);
    translate([3*(w+letter_gap),0]) square([stroke_w,h]);
    translate([3*(w+letter_gap)+stroke_w+letter_gap,0])
        letter_line([[w-r,h-c],[w-c,h-r],[c,h-r],[r,h-c],[r,c],
                     [c,r],[w-c,r],[w-r,c]]);
}
module magic_star() {
    w=star_w/2; h=star_h/2; t=star_tip/2; k=0.55;
    polygon([[-t,h],[t,h],[k,k],[w,t],[w,-t],[k,-k],
             [t,-h],[-t,-h],[-k,-k],[-w,-t],[-w,t],[-k,k]]);
}
module magic_band(length,count,stars) {
    gap=(length-count*word_w-stars*star_w)/(count+stars+1);
    assert(gap>=1.2,"MAGIC lettering has insufficient spacing");
    for(i=[0:count-1]) translate([gap+i*(word_w+star_w+2*gap),0]) {
        magic_word();
        if(i<stars) translate([word_w+gap+star_w/2,letter_h/2]) magic_star();
    }
}
module wall_label(position,angle,length,count,stars) {
    translate([position.x,position.y,(case_top-letter_h)/2])
        rotate([0,0,angle]) rotate([90,0,0]) translate([0,0,-mark_depth])
            linear_extrude(mark_depth+eps) magic_band(length,count,stars);
}
module perimeter_labels() {
    x0=case_min.x; x1=x0+case_size.x; y0=case_min.y; y1=y0+case_size.y;
    // Six MAGIC words and five four-point stars, distributed over all walls.
    // Glyphs are constructed in Cartesian coordinates. Apply the inverse
    // conversion here so the output transform does not mirror the lettering.
    pcb_to_world() {
        wall_label([x0+corner_r,y0],0,case_size.x-2*corner_r,2,2);
        wall_label([x1,y0+corner_r],90,case_size.y-2*corner_r,1,1);
        wall_label([x1-corner_r,y1],180,case_size.x-2*corner_r,2,2);
        wall_label([x0,y1-corner_r],270,case_size.y-2*corner_r,1,0);
    }
}
module base() {
    difference() {
        union() {
            slab(0,floor_t);
            perimeter_shell(floor_t-eps,seam_z);
            pcb_seats();
            for(i=[0:1]) axis(i) cylinder_z(boss_d,floor_t-eps,boss_top);
        }
        insert_bores();
        // Screw force bears on the bosses, never on the shield PCB.
        for(i=[0:1]) axis(i) cylinder_z(lid_pad_d+2*fit,boss_top,case_top+eps);
        if(show_labels) perimeter_labels();
    }
}
module skirt() {
    difference() {
        difference() {
            slab(seam_z-skirt_drop,seam_z+eps,skirt_inset);
            slab(seam_z-skirt_drop-eps,seam_z+2*eps,skirt_inset+skirt_t);
        }
        for(i=[0:1]) axis(i) cylinder_z(boss_d+2*fit,0,case_top+eps);
    }
}
module hold_downs() {
    for(y=support_ys) {
        box([-5.0,y,pcb_top+pcb_hold_gap],[pcb_bearing,y+support_depth,seam_z+eps]);
        box([pcb_w-pcb_bearing,y,pcb_top+pcb_hold_gap],[44.0,y+support_depth,seam_z+eps]);
    }
}
module lid() {
    difference() {
        union() {
            slab(seam_z,case_top);
            skirt(); hold_downs();
            for(i=[0:1]) axis(i) cylinder_z(lid_pad_d,boss_top,seam_z+eps);
        }
        for(i=[0:1]) axis(i) cylinder_z(screw_hole_d,boss_top-eps,case_top+eps);
        openings();
    }
}

// XY datums from shield Rev. 0.1. Heights are nominal component envelopes.
module module_reference() {
    color([0.12,0.12,0.14]) for(x=[3.98,19.22])
        box([x-1.25,1.1,pcb_top+socket_h],[x+1.25,21.42,module_z]);
    color([0.12,0.14,0.19]) box([module_x,0,module_z],[module_x+module_w,pcb_d,module_top]);
    color([0.6,0.64,0.68]) box([module_center-4.5,-1,module_top],
        [module_center+4.5,6,module_top+usb_shell_h]);
    color([0.25,0.28,0.3]) box([6.5,8,module_top],[16.7,20,module_top+2.2]);
}
module shield_reference(with_module=true) {
    color([0.08,0.37,0.23]) box([0,0,pcb_z],[pcb_w,pcb_d,pcb_top]);
    color([0.12,0.12,0.14]) for(x=[3.98,19.22])
        box([x-1.25,0.85,pcb_top],[x+1.25,21.67,pcb_top+socket_h]);
    if(with_module) module_reference();
    color([0.08,0.08,0.10]) difference() {
        box([24.35,4.4,pcb_top],[33.35,22.22,pcb_top+8.75]);
        box([25.35,5.4,pcb_top+2],[32.35,21.22,pcb_top+8.8]);
        box([24.3,11.1,pcb_top+2],[25.4,15.5,pcb_top+8.8]);
    }
    color([0.1,0.1,0.12]) box([26.31,0.38,pcb_top],[31.39,2.92,pcb_top+2.5]);
    color([0.82,0.67,0.28]) {
        for(x=[27.58,30.12],y=[1.65,9.5,12.04,14.58,17.12])
            box([x-0.32,y-0.32,pcb_z-2],[x+0.32,y+0.32,pcb_top+8.5]);
        for(x=[3.98,19.22],n=[0:7]) {
            y=2.37+n*2.54;
            box([x-0.32,y-0.32,pcb_z-2],[x+0.32,y+0.32,pcb_top]);
        }
        for(y=[1.2,8.82,11.12,18.74])
            translate([36,y,pcb_z-2]) cylinder(d=0.6,h=pcb_t+2);
        for(x=[34.73,37.27])
            translate([x,20.75,pcb_z-2]) cylinder(d=0.6,h=pcb_t+2);
    }
    color([0.75,0.66,0.44]) for(y=[5.01,14.93])
        box([34.95,y-1.85,pcb_top],[37.05,y+1.85,pcb_top+2.1]);
    color([0.85,0.05,0.03]) translate([36,20.75,pcb_top]) cylinder(d=3.2,h=5.5);
}
module fasteners() {
    for(i=[0:1]) axis(i) {
        color([0.73,0.52,0.2]) difference() {
            cylinder_z(insert_bore_d,insert_bottom,insert_top);
            cylinder_z(2,insert_bottom-eps,insert_top+eps);
        }
        color([0.22,0.23,0.25]) {
            cylinder_z(2,screw_tip,case_top);
            difference() {
                cylinder_z(screw_head_d,case_top,case_top+screw_head_h);
                translate([0,0,case_top+screw_head_h-1.2]) cylinder(d=1.75,h=1.3,$fn=6);
            }
        }
    }
}
module usb_plug_reference() {
    box([module_center-usb_plug_w/2,-15,usb_center_z-usb_plug_h/2],
        [module_center+usb_plug_w/2,-0.8,usb_center_z+usb_plug_h/2]);
}
module cable_reference() {
    // Mating plug and shunt keepouts: confirm against the actual cable.
    box([23.9,3.9,pcb_top+8.75],[33.8,22.72,case_top+20]);
    box([26.0,0.1,pcb_top+3],[31.7,3.2,case_top+20]);
}
module case_assembly() { base(); lid(); }
module display(lift=0) {
    color(white) base();
    color(white) translate([0,0,lift*2]) lid();
    if(show_hardware) {
        translate([0,0,lift]) shield_reference(false);
        translate([0,0,lift*3]) module_reference();
        translate([0,0,lift*2.4]) fasteners();
    }
}
module printed_lid() { translate([0,pcb_d,case_top]) rotate([180,0,0]) lid(); }

pcb_to_world() {
if(part=="base") base();
else if(part=="lid") printed_lid();
else if(part=="assembly") display();
else if(part=="exploded") display(explode);
else if(part=="section") intersection() { display(); box([-20,-10,-1],[70,pcb_d/2,30]); }
else if(part=="layout") {
    color(white) base();
    color(white) translate([0,-case_size.y-6,0]) printed_lid();
}
else if(part=="led_membrane_probe") intersection() {
    lid();
    translate([led_center.x,led_center.y,0]) cylinder(d=3.2,h=case_top+eps);
}
else if(part=="collision_case") intersection() { base(); lid(); }
else if(part=="collision_hardware") intersection() { case_assembly(); shield_reference(); }
else if(part=="collision_fasteners") intersection() { case_assembly(); fasteners(); }
else if(part=="collision_usb") intersection() { case_assembly(); usb_plug_reference(); }
else if(part=="collision_cable") intersection() { case_assembly(); cable_reference(); }
else if(part=="collision_lid_path") for(dz=[0.2,0.5,1,2,4,8,15,25])
    intersection() {
        union() { base(); shield_reference(false); }
        translate([0,0,dz]) lid();
    }
else if(part=="collision_module_path") for(dz=[0,0.2,0.5,1,2,4,8,15,25])
    intersection() { case_assembly(); translate([0,0,dz]) module_reference(); }
else assert(false,"Unknown output part");
}

echo(case_mm=[case_size.x,case_size.y,case_top],pcb_lower_z=pcb_z,
     module_lower_z=module_z,insert_top_z=insert_top,screw_tip_z=screw_tip,
     insert_thread_engagement=insert_length,tip_floor_clearance=tip_clearance);
