// Welcome to SwiftProcessing

// NOTE: If your program runs slowly, wrap each line in () to bypass the counter.

import PlaygroundSupport
import UIKit

class MySketch: Sketch, SketchDelegate {
    
    var rows = 8
    var cols = 6
    var padding : Double?
    var b = [Bool]()
    
    func setup() {
        padding = 0
    }
    
    func draw() {
        (b = [])
        for _ in 0..<cols*rows {
            let r: Bool
            (r = random(2) == 0 ? true : false)
            (b.append(r))
        }
        
        (background(#colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)))
        (noStroke())
        
        for i in 0..<b.count {
            let x: Double = (Double(calcX(i, cols)))
            let y: Double = (Double(calcY(i, cols)))
            
            if b[i] == true { (fill(#colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)))} else { (fill(#colorLiteral(red: 0.2196078449, green: 0.007843137719, blue: 0.8549019694, alpha: 1)))}
            
            let tx: Double = (x * width/cols)
            let ty: Double = (y * height/rows)
            
            (push())
            (translate(tx, ty))
            let rx = x + padding!
            let ry = y + padding!
            let rw = width/cols - padding! * 2.0
            let rh = height/rows - padding! * 2.0
            (rect(rx,ry,rw,rh))
            
            (pop())
        }
        
        (stroke(#colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)))
        (strokeWeight(0.25))
        
//        for i in 1..<rows {
//            (line(0, i * height/rows, width, i * height/rows))
//        }
//
//        for i in 1..<cols {
//            (line(i * width/cols, 0, i * width/cols, height))
//        }
        
        
        
    }
    
    func calcX(_ index: Int, _ xDim: Int) -> Double  {
        let x = (Int(index % xDim))
        return Double(x)
    }
    
    func calcY(_ index: Int, _ xDim: Int) -> Double {
        let y = (Int(index / xDim))
        return Double(y)
    }
}

// Note: Make sure to include the code below for all of your Playground sketches.

PlaygroundPage.current.needsIndefiniteExecution = true
PlaygroundPage.current.setLiveView(MySketch())
