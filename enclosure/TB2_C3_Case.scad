/* TB2 C3 Dev Shield flat dock, Rev. 0.8. Units: mm.
 * Construction coordinates follow the PCB drawing: USB edge y=0, +Y down.
 * Outputs convert once to Cartesian +Y up; PCB lower face stays at pcb_z.
 * Hardware envelopes and physical fit remain unverified.
 * SPDX-License-Identifier: CERN-OHL-P-2.0
 */

/* [Output] */
part = "assembly"; // [assembly,usb_connected,exploded,section,led_section,base,lid,layout,led_membrane_probe,collision_case,collision_hardware,collision_fasteners,collision_usb,collision_cable,collision_lid_path,collision_light_guide_tolerance]
show_hardware = true;
show_labels = true;
explode = 14;

/* [Print fit] */
wall = 1.8;
floor_t = 1.6;
roof_t = 1.2;
fit = 0.25;
pcb_xy_clearance = 0.15;
pcb_hold_gap = 0.2;
solder_clearance = 0.8;
solder_tail_max = 1.3;
solder_relief_floor_t = 0.8;
print_layer_h = 0.2;

/* [ACT light channel] */
light_entry_d = 3.8;
light_exit_d = 3.2;
light_outer_d = 5.6;
light_flat_wall = 0.4;
light_bottom_above_pcb = 2.8;
led_mount_h = 5.4;
led_height_tolerance = 0.5;
led_top_clearance = 0.1;

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
header_spacer_h = 2.5;
module_pcb_t = 1.6;
module_component_h = 2.2;
module_roof_clearance = 0.5;
usb_shell_h = 3.2;
usb_shell_w = 9.0;
usb_plug_w = 16;
usb_plug_h = 9;
usb_port_w = 10.4;
usb_port_h = 4.4;
usb_port_corner_r = 0.6;
usb_tongue_w = 8.4;
usb_tongue_h = 2.4;
usb_tongue_l = 6.65;
usb_body_face_clearance = 0.15;
front_overhang = 1.2;
front_wall_t = 1.0;
j1_mate_center_x = 28.85;
j1_mate_clearance_w = 9.5;
button_access_d = 3.0;

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
module_z = pcb_top + header_spacer_h;
module_top = module_z + module_pcb_t;
usb_center_z = module_top + usb_shell_h/2;
case_top = module_top + max(module_component_h,usb_shell_h)
           + module_roof_clearance + roof_t;
seam_z = case_top - roof_t;
usb_port_floor_z = usb_center_z - usb_port_h/2;
usb_port_top_z = usb_center_z + usb_port_h/2;
case_min = [-7,-front_overhang];
case_size = [53,pcb_d+front_overhang+4];
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
// Approximate NologoTech button centers; check the actual module variant.
button_centers = [[module_x+6.2,8.7],[module_x+11.7,8.7]];
usb_shell_rear_y = 6.4;
service_open_min = [23.5,-0.2];
led_center = [36,20.75];
led_membrane_t = print_layer_h;
light_flat_x = led_center.x-light_entry_d/2-light_flat_wall;
service_open_max = [light_flat_x,22.9];
light_bottom_z = pcb_top+light_bottom_above_pcb;
light_neck_z = pcb_top+led_mount_h+led_height_tolerance+pcb_hold_gap+led_top_clearance;
light_top_z = case_top-led_membrane_t;
word_w = 4*letter_w+stroke_w+4*letter_gap;
white = [0.94,0.95,0.94];
// Narrow wells cover the released PCB's THT pad envelopes; the ribs stay 1.6 mm thick.
solder_reliefs = [
    [0.5,4.95,1.4,21.12],
    [18.25,22.7,1.4,21.12],
    [26.6,31.1,0.7,18.1],
    [33.75,38.2,0.25,21.7]
];

assert(tip_floor>floor_t, "Screw tip relief would breach the floor");
assert(insert_bottom>screw_tip, "Screws must reach the full insert thread");
assert(boss_top>pcb_top && boss_top<seam_z, "Invalid boss / lid bearing heights");
assert(module_z>pcb_top && module_top<case_top,
       "This dock expects a directly soldered module on one header spacer");
assert(service_open_min.x-module_open_max.x>=2*skirt_t, "Aperture bridge too narrow");
assert(pcb_bearing<0.54, "Left support would overlap an outer ESP32 pad");
assert(led_membrane_t>0 && led_membrane_t<roof_t, "Invalid single-layer LED skin");
assert(light_bottom_z<seam_z && light_neck_z<light_top_z,
       "The light channel must extend below the lid and clear the LED tip");
assert(light_flat_wall>=0.4 && light_outer_d>=light_entry_d+2*light_flat_wall,
       "Insufficient light-channel wall thickness");
assert(light_entry_d/2>3.15/2+sqrt(2)*pcb_xy_clearance,
       "LED tolerance envelope does not fit the light-channel entrance");
assert(light_flat_x>33.35+0.15+pcb_xy_clearance,
       "Light channel would touch the maximum header envelope");
assert(mark_depth<wall && (case_top+letter_h)/2<seam_z,
       "Lettering must leave a wall backing and stay below the lid seam");
assert(pcb_z-solder_tail_max>solder_relief_floor_t+0.2,
       "Trim the THT leads to maintain clearance above the floor wells");
assert(front_overhang>front_wall_t && front_overhang-front_wall_t>=pcb_xy_clearance,
       "The front wall must clear the shield PCB edge");
assert(usb_port_w>usb_shell_w && usb_port_w>usb_tongue_w
       && usb_port_h>usb_shell_h && usb_port_h>usb_tongue_h,
       "USB port must clear the receptacle and plug tongue");
assert(usb_port_floor_z>floor_t && case_top-usb_port_top_z>=1.0,
       "USB port must leave a floor sill and a printable top bridge");
assert(usb_shell_rear_y<button_centers[0].y-button_access_d/2-0.5,
       "USB port must leave a bridge before the button access holes");

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
module usb_access_cut() {
    // Rounded USB-C port: the cable overmold stops outside the front face.
    x0 = module_center-usb_port_w/2;
    x1 = module_center+usb_port_w/2;
    y0 = case_min.y-eps;
    y1 = usb_shell_rear_y;
    z0 = usb_port_floor_z;
    z1 = usb_port_top_z;
    r = usb_port_corner_r;
    translate([0,y1,0]) rotate([90,0,0])
        linear_extrude(y1-y0)
            offset(r=r) translate([x0+r,z0+r])
                square([x1-x0-2*r,z1-z0-2*r]);
}
module button_access_holes() {
    for(point=button_centers)
        translate([point.x,point.y,0]) cylinder(d=button_access_d,h=case_top+eps);
}
module light_channel_outer() {
    // A closed D-shaped tube: flatten only the outside toward J1.
    // The narrow side is one 0.4-mm extrusion; the other sides are 0.9 mm.
    intersection() {
        translate([led_center.x,led_center.y,light_bottom_z])
            cylinder(d=light_outer_d,h=case_top-light_bottom_z);
        box([light_flat_x,led_center.y-light_outer_d,light_bottom_z-eps],
            [led_center.x+light_outer_d,led_center.y+light_outer_d,case_top+eps]);
    }
}
module light_channel_bore() {
    translate([led_center.x,led_center.y,0]) {
        cylinder(d=light_entry_d,h=light_neck_z+eps);
        translate([0,0,light_neck_z])
            cylinder(d1=light_entry_d,d2=light_exit_d,h=light_top_z-light_neck_z);
    }
}
module openings() {
    // Leave a continuous roof over the module, with tool access to both buttons.
    box([module_open_min.x,module_open_min.y,0],
        [module_open_max.x,module_open_max.y,seam_z+eps]);
    button_access_holes();
    aperture(service_open_min,service_open_max);
    // Closed, one-layer outer skin above the tapered light channel.
    light_channel_bore();
}
module perimeter_shell(z0,z1) {
    difference() {
        slab(z0,z1);
        slab(z0-eps,z1+eps,wall);
        // Thin only the front wall; the shield PCB starts just behind it.
        box([case_min.x+corner_r,case_min.y+front_wall_t,z0-eps],
            [case_min.x+case_size.x-corner_r,case_min.y+wall+eps,z1+eps]);
    }
}
module pcb_seats() {
    // Bear only on the PCB's unpopulated outer edges, avoiding all pads.
    for(y=support_ys) {
        box([-5.2,y,floor_t-eps],[pcb_bearing,y+support_depth,pcb_z]);
        box([pcb_w-pcb_bearing,y,floor_t-eps],[44.2,y+support_depth,pcb_z]);
        box([-0.6,y,pcb_z-eps],[-pcb_xy_clearance,y+support_depth,pcb_top+0.1]);
        box([pcb_w+pcb_xy_clearance,y,pcb_z-eps],[pcb_w+0.6,y+support_depth,pcb_top+0.1]);
    }
    for(y=[-pcb_xy_clearance-0.3,pcb_d+pcb_xy_clearance])
        box([9,y,floor_t-eps],[13,y+0.3,pcb_top+0.1]);
}
module solder_relief_wells() {
    for(region=solder_reliefs)
        box([region[0],region[2],solder_relief_floor_t],
            [region[1],region[3],floor_t+eps]);
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
    x0=case_min.x; x1=x0+case_size.x;
    // The engraving is defined in world coordinates before the outer Y flip.
    y_back=pcb_d-(case_min.y+case_size.y);
    y_front=pcb_d-case_min.y;
    front_right_x = module_center+usb_port_w/2;
    // Place MAGIC and a small star on opposite sides of the USB-C port.
    pcb_to_world() {
        wall_label([x1-corner_r,y_front],180,
                   x1-corner_r-front_right_x,1,0);
        translate([x0+corner_r+2,y_front,case_top/2])
            rotate([-90,0,0]) translate([0,0,-mark_depth])
                linear_extrude(mark_depth+eps) magic_star();
        wall_label([x1,y_back+corner_r],90,case_size.y-2*corner_r,1,0);
        wall_label([x0+corner_r,y_back],0,case_size.x-2*corner_r,2,2);
        wall_label([x0,y_front-corner_r],270,case_size.y-2*corner_r,1,0);
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
        solder_relief_wells();
        // Screw force bears on the bosses, never on the shield PCB.
        for(i=[0:1]) axis(i) cylinder_z(lid_pad_d+2*fit,boss_top,case_top+eps);
        usb_access_cut();
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
            light_channel_outer();
            skirt(); hold_downs();
            for(i=[0:1]) axis(i) cylinder_z(lid_pad_d,boss_top,seam_z+eps);
        }
        for(i=[0:1]) axis(i) cylinder_z(screw_hole_d,boss_top-eps,case_top+eps);
        openings();
        usb_access_cut();
    }
}

// XY datums from shield Rev. 0.1. Heights are nominal component envelopes.
module module_reference() {
    color([0.12,0.12,0.14]) for(x=[3.98,19.22])
        box([x-1.25,1.1,pcb_top],[x+1.25,21.42,module_z]);
    color([0.12,0.14,0.19]) box([module_x,0,module_z],[module_x+module_w,pcb_d,module_top]);
    color([0.6,0.64,0.68]) box([module_center-usb_shell_w/2,-1,module_top],
        [module_center+usb_shell_w/2,6,module_top+usb_shell_h]);
    color([0.25,0.28,0.3]) box([6.5,8,module_top],
                               [16.7,20,module_top+module_component_h]);
}
module led_reference(worst=false) {
    // WP710A10LID: nominal 5.4-mm mounting envelope, 2.9-mm lens, 3.2-mm flange.
    translate([led_center.x,led_center.y,pcb_top]) {
        if(worst) {
            cylinder(d=3.45,h=1.25);
            cylinder(d=3.15,h=led_mount_h+led_height_tolerance);
        } else {
            cylinder(d=3.2,h=1);
            cylinder(d=2.9,h=led_mount_h-2.9/2);
            translate([0,0,led_mount_h-2.9/2]) sphere(d=2.9);
        }
    }
}
module light_neighbours_envelope() {
    led_reference(true);
    // Conservative per-side header tolerances; axial resistor envelope per BOM.
    box([24.2,4.2,pcb_top],[33.5,22.42,pcb_top+8.9]);
    box([34.95,13.08,pcb_top],[37.05,16.78,pcb_top+2.1]);
}
module shield_reference() {
    color([0.08,0.37,0.23]) box([0,0,pcb_z],[pcb_w,pcb_d,pcb_top]);
    module_reference();
    color([0.08,0.08,0.10]) difference() {
        box([24.35,4.4,pcb_top],[33.35,22.22,pcb_top+8.75]);
        box([25.35,5.4,pcb_top+2],[32.35,21.22,pcb_top+8.8]);
        box([24.3,11.1,pcb_top+2],[25.4,15.5,pcb_top+8.8]);
    }
    color([0.1,0.1,0.12]) box([26.31,0.38,pcb_top],[31.39,2.92,pcb_top+2.5]);
    color([0.82,0.67,0.28]) {
        for(x=[27.58,30.12],y=[1.65,9.5,12.04,14.58,17.12])
            box([x-0.32,y-0.32,pcb_z-solder_tail_max],
                [x+0.32,y+0.32,pcb_top+8.5]);
        for(x=[3.98,19.22],n=[0:7]) {
            y=2.37+n*2.54;
            box([x-0.32,y-0.32,pcb_z-solder_tail_max],
                [x+0.32,y+0.32,pcb_top]);
        }
        for(y=[1.2,8.82,11.12,18.74])
            translate([36,y,pcb_z-solder_tail_max])
                cylinder(d=0.6,h=pcb_t+solder_tail_max);
        for(x=[34.73,37.27])
            translate([x,20.75,pcb_z-solder_tail_max])
                cylinder(d=0.6,h=pcb_t+solder_tail_max);
    }
    color([0.75,0.66,0.44]) for(y=[5.01,14.93])
        box([34.95,y-1.85,pcb_top],[37.05,y+1.85,pcb_top+2.1]);
    color([0.85,0.05,0.03]) led_reference();
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
    union() {
        // USB-C metal tongue crosses the wall; the overmold remains outside it.
        body_end_y = case_min.y-usb_body_face_clearance;
        box([module_center-usb_plug_w/2,-15,usb_center_z-usb_plug_h/2],
            [module_center+usb_plug_w/2,body_end_y,usb_center_z+usb_plug_h/2]);
        box([module_center-usb_tongue_w/2,body_end_y,usb_center_z-usb_tongue_h/2],
            [module_center+usb_tongue_w/2,body_end_y+usb_tongue_l,
             usb_center_z+usb_tongue_h/2]);
    }
}
module cable_reference() {
    // Reference female IDC is 8.45 +/- 0.15 mm wide, plus model clearance.
    box([j1_mate_center_x-j1_mate_clearance_w/2,3.9,pcb_top+8.75],
        [j1_mate_center_x+j1_mate_clearance_w/2,22.72,case_top+20]);
    box([26.0,0.1,pcb_top+3],[31.7,3.2,case_top+20]);
}
module case_assembly() { base(); lid(); }
module display(lift=0) {
    color(white) base();
    color(white) translate([0,0,lift*2]) lid();
    if(show_hardware) {
        translate([0,0,lift]) shield_reference();
        translate([0,0,lift*2.4]) fasteners();
    }
}
module printed_lid() { translate([0,pcb_d,case_top]) rotate([180,0,0]) lid(); }
module light_section() {
    color(white) render() intersection() {
        lid(); box([31.5,17,pcb_top-0.2],[40.5,led_center.y,case_top+0.2]);
    }
    color([0.85,0.05,0.03]) render() intersection() {
        led_reference(); box([31.5,17,pcb_top-0.2],[40.5,led_center.y,case_top+0.2]);
    }
    color([0.08,0.37,0.23])
        box([31.5,17,pcb_z],[pcb_w,led_center.y,pcb_top]);
    color([0.08,0.08,0.1]) box([31.5,17,pcb_top],[33.35,led_center.y,pcb_top+8.75]);
}

pcb_to_world() {
if(part=="base") base();
else if(part=="lid") printed_lid();
else if(part=="assembly") display();
else if(part=="usb_connected") {
    display();
    color([0.08,0.08,0.09]) usb_plug_reference();
}
else if(part=="exploded") display(explode);
else if(part=="section") intersection() { display(); box([-20,-10,-1],[70,pcb_d/2,30]); }
else if(part=="led_section") light_section();
else if(part=="layout") {
    color(white) base();
    color(white) translate([0,-case_size.y-6,0]) printed_lid();
}
else if(part=="led_membrane_probe") intersection() {
    lid();
    // Stay inside the tapered bore edge to avoid coincident probe faces.
    translate([led_center.x,led_center.y,0]) cylinder(d=light_exit_d-0.1,h=case_top+eps);
}
else if(part=="collision_case") intersection() { base(); lid(); }
else if(part=="collision_hardware") intersection() { case_assembly(); shield_reference(); }
else if(part=="collision_fasteners") intersection() { case_assembly(); fasteners(); }
else if(part=="collision_usb") intersection() { case_assembly(); usb_plug_reference(); }
else if(part=="collision_cable") intersection() { case_assembly(); cable_reference(); }
else if(part=="collision_lid_path") for(dz=[0.2,0.5,1,2,4,8,15,25])
    intersection() {
        union() { base(); shield_reference(); }
        translate([0,0,dz]) lid();
    }
else if(part=="collision_light_guide_tolerance") intersection() {
    lid();
    union() for(dx=[-pcb_xy_clearance,pcb_xy_clearance],
                dy=[-pcb_xy_clearance,pcb_xy_clearance],dz=[0,pcb_hold_gap])
        translate([dx,dy,dz]) light_neighbours_envelope();
}
else assert(false,"Unknown output part");
}

echo(case_mm=[case_size.x,case_size.y,case_top],pcb_lower_z=pcb_z,
     module_lower_z=module_z,insert_top_z=insert_top,screw_tip_z=screw_tip,
     insert_thread_engagement=insert_length,tip_floor_clearance=tip_clearance);
