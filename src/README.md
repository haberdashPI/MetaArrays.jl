# MetaArrays

A `MetaArray` stores extra data as a named tuple along with an array. It
otherwise behaves much as the stored array. 

You create a meta array by calling `meta` with the specified metadata as keyword
arguments; any operations over the array will preserve the metadata, and
the metadata can be accessed as fields of the object.

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
values you can call `MetaArrays.combine` which takes two named tuples containing
the to-be-merged metadata and combines them into a single named tuple.

# AxisArrays

MetaArrays is aware of `AxisArrays` and the wrapped meta arrays
implement the same set of methods as other `AxisArray` objects, and
will preserve axes across broadcasting.
