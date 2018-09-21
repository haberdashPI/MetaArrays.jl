# MetaArrays

MetaArrays store extra data along with an array, in the fields `meta` and
`data`, respectively. It otherwise behaves much like the wrapped array. 

For example:

```julia
julia> y = meta((val1 = "value1",),rand(10,10))
julia> x = meta((val2 = "value2",),rand(10,10))

julia> z = x.*y
julia> z.meta
(val1 = "value1", val2 = "value2)
```

A `MetaArray` has the same array interface behavior, broadcasting behavior and
strided array behavior as the wrapped array. The metadata is maintained
throughout these transformations of the data. To implement further methods
which support maintaining meta-data you can specialize over `MetaArray{A}`
where `A` is the wrapped array type.

For example

```julia
mymethod(x::MetaArray{<:MyArrayType},y::MetaArray{<:MyArrayType}) = 
   meta(metamerge(x.meta,y.meta),mymethod(x.data,y.data))
```

The metadata can be any type. The method `metamerge` falls back to 
`merge` for `AbstractDict` and `NamedTuple` types, and if you 
wish to use a custom metadata type, you can define new methods
for `metamerge` to ensure it properly merges.

MetaArrays is aware of `AxisArrays` and the wrapped meta arrays
implement the same set of methods as other `AxisArray` objects.
