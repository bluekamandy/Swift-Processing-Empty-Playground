// Welcome to SwiftProcessing

// NOTE: If your program runs slowly, wrap each line in () to bypass the counter.

import PlaygroundSupport
import UIKit

class MySketch: Sketch, SketchDelegate {

    func setup() {
    }
    
    func draw() {
    }
    
}

// Note: Make sure to include the code below for all of your Playground sketches.

PlaygroundPage.current.needsIndefiniteExecution = true
PlaygroundPage.current.setLiveView(MySketch())
