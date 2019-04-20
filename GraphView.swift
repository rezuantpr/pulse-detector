//
//  GraphView.swift
//  PulseDetectorTest
//
//  Created by  Rezuan on 20/04/2019.
//  Copyright © 2019  Rezuan. All rights reserved.
//

import UIKit

class GraphView: UIView {

    private func drawLines(in rect: CGRect) {
        let path = UIBezierPath()
        var dots: [CGFloat] = [0, 2, 2, 1.5, 0.5, 2.5, 1, 0, 20]
//        let point1 = CGPoint(x: 0, y: rect.origin.y + rect.height / 2)
//        let point2 = CGPoint(x: rect.width / 2, y: rect.origin.y)
//        let point3 = CGPoint(x: rect.width, y: rect.origin.y + rect.height / 2)
        let minY: CGFloat = rect.height
        let maxY: CGFloat = rect.origin.y
        let step = rect.width / CGFloat(dots.count)
        print(rect.height)
        
        func scale(x: CGFloat, a: CGFloat, b: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
            return ((b - a) * (x - min))/(max - min) + a
        }
        
        func drawCircular(with center: CGPoint) {
            let radius: CGFloat = 2
            
            let path = UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: false)
            
            path.lineWidth = 5
            path.lineCapStyle = .round
            
            let color = UIColor.green
            color.setStroke()
            
            path.stroke()
        }
        
        for i in 0 ..< dots.count {
            let point = CGPoint(x: step * CGFloat(i), y:  scale(x: CGFloat(dots[i]), a: minY, b: maxY, min: dots.min()!, max: dots.max()!))
            print(point)
            if i == 0 {
                path.move(to: point)
                drawCircular(with: point)
            } else {
                path.addLine(to: point)
                drawCircular(with: point)
            }
        }
        
        path.lineWidth = 2
        
        let color = UIColor.green
        color.setStroke()
        path.stroke()
    }
    
   
    
    override func draw(_ rect: CGRect) {
        
        drawLines(in: rect) //тут работать с линиями
    }

}
