import Foundation

@usableFromInline
let _sqrt5 = sqrt(5.0)

@usableFromInline
let _phi = (1 + _sqrt5) / 2

@inlinable
@inline(__always)
func fibonacci(_ n: Int) -> Int {
  Int((pow(_phi, Double(n)) / _sqrt5).rounded())
}
