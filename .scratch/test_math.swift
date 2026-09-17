import Foundation
let math = "10 + 20 * 3"
let exp = NSExpression(format: math)
if let result = exp.expressionValue(with: nil, context: nil) as? NSNumber {
    print(result.intValue)
}
