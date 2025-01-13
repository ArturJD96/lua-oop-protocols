# lua-oop-protocols
Swift-inspired protocols (interfaces) for lua scripts.

## Introduction: Lua, OOP and dynamic typing headaches.
Lua dynamic typing often sacrifices code safety for the sake of flexibility.
This allows for arriving quickly at simple solutions for small tasks.
However, as the project grows, using dynamic type languages risks unexpected behaviours
during execution, lowering developer's trust to their own code and increasing time spent on debugging.
This is why developers often prefer more strong typed languages when aiming at developing safe
and extendable code (as is the case in webdev of choosing TypeScript over vanilla Javascript).

Many code solutions to real-life problems take form of creating virtual entities (objects),
whose properties, behaviour and interaction imitate their real-life counterparts.
The so called "object-orienter programming" (OOP) approach aims at coding style that can be
intuitively grasped by human reader. Lua scripting can definitely cherish from many OOP merits,
allowing adoption of various OOP styles.

A main obstacle when applying OOP patterns to Lua is the mentioned languages's dynamic type system.
Unless explicitly stated, objects cannot verify types and "shape" of other objects
during runtime. The infamous "attempt to index a nil value" errors's main dread is
not in how frequently it appears, but how useless it is for debugging,
pointing at the source line instead of explicitly stating error's true source (wrong object at wrong place).
Even worse: objects may keep on passing the ill-shaped objects:
until sh*t hits the fan for real there is no feedback at all that something goes seriously wrong from the start.
With intention to protect against those situations, many additional lines of type assertion code
clutter our initially seemingly elegant scripts.

Last but not least, OOP itself must be applied with care. Many patterns invented and praised in the past
have been understood as unacceptable and harming our code design today (or even language designs themselves).
(One such a recommendation, perhaps surprising for many OOP veterans,
is to define the core design features of the software in terms of simple objects – not classes!).
Most of the "attempts to index a nil value" errors could have been avoided altogether if a different approach was applied.
This however requires much more experience than just learning the language well.

Thus, Lua deserves a solution that reconciles healthy and modern OOP practices with Lua dynamic-type flexibility.

## Goal of this package
This package aims at bringing to Lua an OOP framework that favours object's [composition over inheritance](https://sheldonrcohen.medium.com/favoring-composition-over-inheritance-ff2ece6b7b4e)]
in place of the more legacy class inheritance model. Centering around objects (in Lua usually represented as tables),
it does not limit the flexibility offered by Lua tables.

The protocol package facilitates writing safe table-based and type-checked, classes, constructors and factories.
It focuses heavily on type validation of all the table/object properties (called here "fields") during object creation.

Having looked for the best pattern encouraging the developer to write a shallow, self-documenting and extendable code,
I decided to base this package on the idea of _protocols_ found in Swift.

### Inspiration: Swift protocols
In computer science, "Protocol" is a term having many meanings.
In [Swift](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/protocols/)
programming language, a _protocol_ is a blueprint for an object.
An object _conforms_ to a protocol when it implements all the protocol's properties.
Notice that in protocol those properties do not have yet any values. Those must be assigned at the object creation.
```Swift
protocol VehicleRegistrable {
    var wheels: Int { get }
    var plate: String { get set }
    func drive(km:Int) -> PetrolCostReturn
}
struct Fiat: VehicleRegistrable {
    let wheels = 4
    let plate = "ABC-123"
    func drive(km:Int) -> PetrolCostReturn {
        return PetrolCostReturn.calc(km)
    }
}
```
If you do not satisfy the protocol, you will get an error!
```Swift
struct StolenMercedes: VehicleRegistrable {
    let wheels = 4
    func drive(km:Int) -> PetrolCostReturn {
        return PetrolCostReturn.calc(km)
    }
    // raising error! No 'plate' property implemented.
}
```
There are many details here. You can also have protocols with default values.

### Protocols and classes in Swift
Notice that the example above works on the level of single objects, not classes.
In Swift, you can however conform a class to the protocol as well. This way, you can create more objects using class constructor.
```Swift
class LegalVehicle: VehicleRegistrable {
    let wheels: Int
    let plate: String
    init(wheels: Int, plate: String) {
        self.wheels = wheels
        self.plate = plate
    }
    func drive(km:Int) -> PetrolCostReturn {
        return PetrolCostReturn.calc(km)
    }
}
```

### Why "protocol", not "interface"?
Another, maybe even more wide-spread term, coming mostly from Java and adopted in many other programming languages, is "interface".
You may be even more familiar with this one. Why then I decided to use Swift terminology?

Swift protocols differs from Java's protocol. For example, in Java it is the class that accepts the interface,
while in Swift the object itself conforms to the protocol.
```Java
interface VehicleRegistrable {
  PetrolCostReturn drive(int km);
}
class AlphaRomeo : VehicleRegistrable {
  // implementation...
}
```
For more details see [this article](https://paigeshin1991.medium.com/swift-protocols-vs-other-languages-interfaces-understanding-the-differences-9e49be7f6769).

I believe that this "Javaesque" approach doesn't suit well the flexibility led behind Lua tables and metatables.
Of course, due to a completely differnt nature of Lua and Swift, many features of original Swift protocols cannot be translated directly
into the Lua realm (the restrictions applied to mutating the properties after object creations being the first features that have to go).
However, it is the approach towards composition that Swift protocols promote that founds the thinking behind this Lua package;
hence the decision to call it protocol.

# Main features
