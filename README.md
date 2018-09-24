# MetaArrays

A `MetaArray` stores extra data as a named tuple along with an array, which can
be accessed as fields of the array object. It otherwise behaves much as the
stored array. 

You create a meta array by calling `meta` with the specified metadata as keyword
arguments; any operations over the array will preserve the metadata.

For example:

```julia
julia> y = meta(rand(10,10),val1="value1")
julia> x = meta(rand(10,10),val2="value2")

julia> z = x.*y
julia> z.val1
"value1"
```

A `MetaArray` has the same array behavior, broadcasting behavior and strided
array behavior as the wrapped array, while maintaining the metadata. To
implement further methods which support maintaining meta-data you can specialize
over `MetaArray{A}` where `A` is the wrapped array type.  

For example

```julia
mymethod(x::MetaArray{<:MyArrayType},y::MetaArray{<:MyArrayType}) = 
   meta(metamerge(x.meta,y.meta),mymethod(x.data,y.data))
```

# Merging Metadata

During broadcasting, all metadata fields are combined into a single named tuple.
If a given field is shared across arguments and its values are not `===` it is
merged using `metamerge`, which is defined for `Dict` and `NamedTuple` objects
as `merge`. 

You can define your own `metamerge` methods to enable merging of other types. 

If you wish to leverage this merging facility in your own methods of `MetaArray`
values you can call `MetaArrays.combine` which takes two metadata objects and
combines them into a single object using `metamerge`, while checking
for any issues while merging identical fields.

# AxisArrays

MetaArrays is aware of `AxisArrays` and the wrapped meta arrays implement the
same set of methods as other `AxisArray` objects, and will preserve axes across
broadcasting.

# Custom metadata types

Sometimes it is useful to dispatch on the type of the metadata.  To make this
possible, you can provide a custom type as metadata rather than fields of a
named tuple.  This can be done by passing your custom object `meta` to
`MetaData(meta,data)`. For metadata to appropriately merge you will need to
define `mergemeta` for this type. Just as with named tuples, the fields of the
custom type can be accessed directly from the metarray.

Once your custom type is defined you can dispatch on the second type parameter
of the MetaArray, like so:

```julia
struct MyCustomMetadata
  val::String
end 

foo(x::MetaArray{<:Any,MyCustomMetadata}) = x.val
x = MetaArray(MyCustomMetadata("Hello, World"),1:10)
println(foo(x))
