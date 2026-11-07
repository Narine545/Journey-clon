"""Standard-library mirror of IslandLayout's analytic terrain; not Godot execution."""
import math

CENTER = (170., 5.)
AXES = (230., 285.)
BAY_INNER = (88., -30.)
BOAT_START = (-160., -30.)
BERTH = (114., -38.)
BEARINGS = (-145., -78., 12., 100.)


def smooth(x, lo, hi):
    t = max(0., min(1., (x-lo)/(hi-lo)))
    return t*t*(3-2*t)


def smin(a, b, k):
    h = max(k-abs(a-b), 0)/k
    return min(a, b)-h*h*k*.25


def distance(x, z):
    qx, qz = (x-170)/230, (z-5)/285
    a = math.atan2(qz, qx)
    r = 1+.085*math.sin(3*a+.4)+.045*math.cos(5*a-.6)-.035*math.sin(2*a)+.022*math.cos(9*a+1.2)
    outer = (r-math.hypot(qx, qz))*230
    cx = max(-165, min(88, x))
    delta = cx-88
    mask = smooth(abs(delta), 0, 42)
    cz = -30+(7*math.sin(delta*.011)+3*math.sin(delta*.027))*mask
    width = 62+(6*math.sin(delta*.017)+2*math.sin(delta*.039))*mask
    a = math.atan2(z-cz, x-cx)
    irregular = (3.8*math.sin(3*a)+1.6*math.cos(4*a))*smooth(math.hypot(x-cx, z-cz), 20, 50)
    channel = math.hypot(x-cx, z-cz)-width-irregular
    east = (math.hypot((x-410)/58, (z-150)/78)-1)*58
    north = (math.hypot((x-110)/45, (z+296)/38)-1)*38
    return smin(smin(smin(outer, channel, 18), east, 14), north, 12)


def height(x, z):
    d = distance(x, z)
    if d <= 0:
        offshore = -d
        return -100*(1-math.exp(-(.115*offshore+.00125*offshore**2)/100))
    hills = sum(h*math.exp(-((x-cx)/rx)**2-((z-cz)/rz)**2) for cx, cz, rx, rz, h in
                ((218, 0, 95, 150, 23), (150, -174, 82, 85, 12), (205, 175, 105, 88, 16)))
    hills *= 1-.9*math.exp(-((x-188)/82)**2-((z+30)/60)**2)
    h = 8*(1-math.exp(-d/85))+hills*smooth(d, 10, 75)
    h += math.sin(x*.038+math.sin(z*.022))*math.cos(z*.031-.7)*1.1*smooth(d, 12, 65)
    terrace = (1-smooth(math.hypot((x-188)/30, (z+30)/24), .55, 1.55))*smooth(d, 8, 16)
    return h*(1-terrace)+4*terrace


def site(degrees):
    a = math.radians(degrees)
    dx, dz = math.cos(a)*230, math.sin(a)*285
    length = math.hypot(dx, dz)
    dx, dz = dx/length, dz/length
    hi, lo = 470, 0
    for step in range(1, 236):
        r = 470-step*2
        if distance(170+dx*r, 5+dz*r) > 0:
            lo = r
            break
        hi = r
    assert lo > 0
    for _ in range(20):
        mid = (lo+hi)/2
        if distance(170+dx*mid, 5+dz*mid) > 0:
            lo = mid
        else:
            hi = mid
    sx, sz = 170+dx*(lo+hi)/2, 5+dz*(lo+hi)/2
    gx, gz = distance(sx+.5, sz)-distance(sx-.5, sz), distance(sx, sz+.5)-distance(sx, sz-.5)
    gl = math.hypot(gx, gz)
    nx, nz = -gx/gl, -gz/gl
    land = (sx-14*nx, sz-14*nz)
    offshore = 36
    while -height(sx+nx*offshore, sz+nz*offshore) < 4.5 and offshore < 126:
        offshore += 3
    buoy = sx+nx*offshore, sz+nz*offshore
    return land, buoy, (sx, sz), (nx, nz)


def blocks_hull(x, z, yaw, radius=1.7, half=4.4):
    for step in (-1, 0, 1):
        px, pz = x-math.sin(yaw)*step*half, z-math.cos(yaw)*step*half
        if math.hypot(px-max(109, min(160, px)), pz-max(-33, min(-27, pz))) < radius:
            return True
    return False
