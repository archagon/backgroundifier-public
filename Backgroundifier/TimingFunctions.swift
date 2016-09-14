//
//  TimingFunctions.swift
//  Backgroundifier
//
//  Created by Alexei Baboulevitch on 2015-9-12.
//  Copyright (c) 2015 Alexei Baboulevitch. All rights reserved.
//

import Foundation

// cribbed from http://gsgd.co.uk/sandbox/jquery/easing/
// t: current time, b: beginning value, c: change in value, d: duration

func easeInCubic(t: Double, b: Double, c: Double, d: Double) -> Double {
    let t = t/d
    return c*(t)*t*t + b;
}

func easeOutCubic(t: Double, b: Double, c: Double, d: Double) -> Double {
    let t = t/d-1
    return c*((t)*t*t + 1) + b;
}

func easeOutBounce(t: Double, b: Double, c: Double, d: Double) -> Double {
    var t = t/d
    
    if (t < (1/2.75)) {
        return c*(7.5625*t*t) + b;
    } else if (t < (2/2.75)) {
        t = t - (1.5/2.75)
        return c*(7.5625*(t)*t + 0.75) + b;
    } else if (t < (2.5/2.75)) {
        t = t - (2.25/2.75)
        return c*(7.5625*(t)*t + 0.9375) + b;
    } else {
        t = t - (2.625/2.75)
        return c*(7.5625*(t)*t + 0.984375) + b;
    }
}
