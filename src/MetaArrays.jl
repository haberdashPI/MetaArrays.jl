module MetaArrays
export meta, MetaArray

using Requires

function __init__()
  @require AxisArrays="39de3d68-74b9-583c-8d2d-e117c070f3a9" begin
    AxisArrays.axisdim(x::MetaArray{<:AxisArray},ax) =
      axisdim(x.data,ax)
    AxisArrays.axes(x::MetaArray{<:AxisArray},i::Int...) =
      AxisArrays.axes(x.data,i...)
    AxisArrays.axes(x::MetaArray{<:AxisArray},T::Type{<:Axis}...) =
      AxisArrays.axes(x.data,T...)
    AxisArrays.axes(x::MetaArray{<:AxisArray}) = AxisArrays.axes(x.data)
    AxisArrays.axisnames(x::MetaArray{<:AxisArray}) = axisnames(x.data)
    AxisArrays.axisvalues(x::MetaArray{<:AxisArray}) = axisvalues(x.data)
  end
end

struct MetaArray{M,A,T,N} <: AbstractArray{T,N}
  meta::M
  data::A
end

function MetaArray(meta::M,data::A) where {M,T,N,A<:AbstractArray{T,N}}
  MetaArray{M,A,T,N}(meta,data)
end

meta(meta,data) = MetaArray(meta,data)
meta(data;meta...) = MetaArray(meta.data,data)

metamerge(x::NamedTuple,y::NamedTuple) = merge(x,y)
metamerge(x::AbstractDict,y::AbstractDict) = merge(x,y)
function metamerge(x,y) 
  error("There is no known way to merge metadata of type $(typeof(x)) ",
        "and type $(typeof(y)).")
end
struct NoMetaData end
metamerge(x,::NoMetaData) = x

# match array behavior of wrapped array (maintaining the metdata)
Base.size(x::MetaArray) = size(x.data)
Base.axes(x::MetaArray) = Base.axes(x.data)
Base.IndexStyle(x::MetaArray) = IndexStyle(x.data)
@inline @Base.propagate_inbounds Base.getindex(x::MetaArray,i::Int...) =
  getindex(x.data,i...)
@inline @Base.propagate_inbounds Base.getindex(x::MetaArray,i...) =
  metawrap(x,getindex(x.data,i...))
@inline @Base.propagate_inbounds Base.setindex!(x::MetaArray,v,i...) =
  setindex!(x.data,v,i...)
@inline @Base.propagate_inbounds function Base.setindex!(x::MetaArray{T}, v::T,
                                                         i::Int...) where T
  setindex!(x.data,v,i...)
end
function Base.similar(x::MetaArray,::Type{S},dims::NTuple{<:Any,Int}) where S
  meta(x.meta,similar(x.data,S,dims))
end

metawrap(x::MetaArray{<:Any,<:Any,T},val::T) where T = val
keepmeta(x::MetaArray,dims) = true
function metawrap(x::MetaArray,val::AbstractArray) 
  keepmeta(x,val) ? MetaArray(x.meta,val) : val
end
metawrap(x::MetaArray,val::MetaArray) = val
metawrap(x::MetaArray,val) = error("Unexpected result type $(typeof(val)).")

# maintain stridedness of wrapped array, if present
Base.strides(x::MetaArray) = strides(x.data)
Base.unsafe_convert(T::Type{<:Ptr},x::MetaArray) = unsafe_convert(T,x.data)
Base.stride(x::MetaArray,i::Int) = stride(x.data,i)

# the meta array braodcast style should retain the nested style information for
# whatever array type the meta array wraps
struct MetaArrayStyle{S} <: Broadcast.BroadcastStyle 
  s::Type{S}
end
MetaArrayStyle(s::S) where S <: Broadcast.BroadcastStyle = MetaArrayStyle{S}(S)
Base.Broadcast.BroadcastStyle(::Type{<:MetaArray{<:Any,A}}) where A = 
  MetaArrayStyle(Broadcast.BroadcastStyle(A))
Base.Broadcast.BroadcastStyle(a::MetaArrayStyle{A},b::MetaArrayStyle{B}) where {A,B} =
  MetaArrayStyle(BradcastStyle(A(),B()))
function Base.Broadcast.BroadcastStyle(a::MetaArrayStyle{A},b::B) where 
  {A,B<:Broadcast.BroadcastStyle}

  MetaArrayStyle(Broadcast.BroadcastStyle(A(),b))
end

# helper functions to simultaneously extract and merge the meta data across all
# arguments, and the broadcasted object that would be created by wrapped arrays
# of the meta-arrays
find_meta_style(bc::Broadcast.Broadcasted) = find_ms_helper(bc,bc.args...)
find_meta_style(x) = NoMetaData(), x
find_meta_style(x::MetaArray) = x.meta, x.data

find_ms_helper(bc::Broadcast.Broadcasted,x::MetaArray) =
  x.meta, Broadcast.broadcasted(bc.f,x.data)
find_ms_helper(bc::Broadcast.Broadcasted,x) = NoMetaData(), bc
function find_ms_helper(bc::Broadcast.Broadcasted,x::MetaArray,rest)
  meta, broadcasted = find_meta_style(rest)
  metamerge(x.meta,meta), Broadcast.broadcasted(bc.f,x.data,broadcasted)
end
function find_ms_helper(bc::Broadcast.Broadcasted,x,rest)
  meta, broadcasted = find_meta_style(rest)
  meta, Broadcast.broadcasted(bc.f,x.data,broadcasted)
end

# the wrapped arrays may define custom machinery for broadcasting:
# for in-place and out-of-place broadcasting extract the meta-data and use the
# same broadcast implementation the wrapped arrays would use to
# find the resulting data

# note: in-place broadcast cannot extract the meta data
# since we have to assume the metadata could be immutable.
function Base.copyto!(dest::AbstractArray, 
                      bc::Broadcast.Broadcasted{MetaArrayStyle{A}}) where A
  _, broadcasted = find_meta_style(bc)
  copyto!(dest, broadcasted)
end

function Base.copyto!(dest::MetaArray, bc::Broadcast.Broadcasted{Nothing})
  copyto!(dest.data,bc)
end

function Base.copy(bc::Broadcast.Broadcasted{MetaArrayStyle{A}}) where A
  meta, broadcasted = find_meta_style(bc)
  MetaArray(meta, copy(broadcasted))  
end

end # module
