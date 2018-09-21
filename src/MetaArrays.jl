module MetaArrays
export meta, MetaArray

using Requires

function __init__()
  @require AxisArrays="39de3d68-74b9-583c-8d2d-e117c070f3a9" begin
    AxisArrays.axisdim(x::MetaArray{<:AxisArray},ax) =
      axisdim(getdata(x),ax)
    AxisArrays.axes(x::MetaArray{<:AxisArray},i::Int...) =
      AxisArrays.axes(getdata(x),i...)
    AxisArrays.axes(x::MetaArray{<:AxisArray},T::Type{<:Axis}...) =
      AxisArrays.axes(getdata(x),T...)
    AxisArrays.axes(x::MetaArray{<:AxisArray}) = AxisArrays.axes(getdata(x))
    AxisArrays.axisnames(x::MetaArray{<:AxisArray}) = axisnames(getdata(x))
    AxisArrays.axisvalues(x::MetaArray{<:AxisArray}) = axisvalues(getdata(x))
  end
end

struct MetaArray{A,M<:NamedTuple,T,N} <: AbstractArray{T,N}
  meta::M
  data::A
end

function MetaArray(meta::M,data::A) where 
  {M<:NamedTuple,T,N,A<:AbstractArray{T,N}}

  MetaArray{A,M,T,N}(meta,data)
end
meta(data::AbstractArray;meta...) = MetaArray(meta.data,data)
Base.getproperty(x::MetaArray,name::Symbol) = getproperty(getmeta(x),name)
getdata(x::MetaArray) = Base.getfield(x,:data)
getmeta(x::MetaArray) = Base.getfield(x,:meta)
function meta(data::MetaArray;meta...)
  MetaArray(getdata(data),merge(getmeta(data),meta)...)
end

struct UnknownMerge{A,B} end
metamerge(x::NamedTuple,y::NamedTuple) = merge(x,y)
metamerge(x::AbstractDict,y::AbstractDict) = merge(x,y)
function metamerge(x::A,y::B) where {A,B} 
  x === y ? y : UnknownMerge{A,B}()
end

function checkmerge(k,v::UnknownMerge{A,B}) where {A,B}
  error("The field `$k` has non-identical values across metadata ",
        "and there is no known way to merge an object of type $A with an",
        " object of type $B. You can fix this by defining ",
        "`MetaArrays.metamerge` for these types.")
end
checkmerge(k,v) = nothing

# TOOD: file an issue with julia about mis-behavior of `merge`.
function combine(x::NamedTuple,y::NamedTuple) 
  result = combine_(x,iterate(pairs(x)),y)
  for (k,v) in pairs(result); checkmerge(k,v); end

  result
end
combine_(x,::Nothing,result) = result
function combine_(x,((key,val),state),result)
  newval = haskey(result,key) ? metamerge(val,result[key]) : val
  entry = NamedTuple{(key,)}((newval,))
  combine_(x,iterate(x,state),merge(result,entry))
end

struct NoMetaData end
combine(x,::NoMetaData) = x

# match array behavior of wrapped array (maintaining the metdata)
Base.size(x::MetaArray) = size(getdata(x))
Base.axes(x::MetaArray) = Base.axes(getdata(x))
Base.IndexStyle(x::MetaArray) = IndexStyle(getdata(x))
@inline @Base.propagate_inbounds Base.getindex(x::MetaArray,i::Int...) =
getindex(getdata(x),i...)
@inline @Base.propagate_inbounds Base.getindex(x::MetaArray,i...) =
metawrap(x,getindex(getdata(x),i...))
@inline @Base.propagate_inbounds Base.setindex!(x::MetaArray{<:Any,<:Any,T},v,i...) where T =
setindex!(getdata(x),v,i...)
@inline @Base.propagate_inbounds function Base.setindex!(x::MetaArray{<:Any,<:Any,T}, v::T,i::Int...) where T
  setindex!(getdata(x),v,i...)
end
function Base.similar(x::MetaArray,::Type{S},dims::NTuple{<:Any,Int}) where S
  MetaArray(getmeta(x),similar(getdata(x),S,dims))
end

metawrap(x::MetaArray{<:Any,<:Any,T},val::T) where T = val
keepmeta(x::MetaArray,dims) = true
function metawrap(x::MetaArray,val::AbstractArray) 
  keepmeta(x,val) ? MetaArray(getmeta(x),val) : val
end
metawrap(x::MetaArray,val::MetaArray) = val
metawrap(x::MetaArray,val) = error("Unexpected result type $(typeof(val)).")

# maintain stridedness of wrapped array, if present
Base.strides(x::MetaArray) = strides(getdata(x))
Base.unsafe_convert(T::Type{<:Ptr},x::MetaArray) = unsafe_convert(T,getdata(x))
Base.stride(x::MetaArray,i::Int) = stride(getdata(x),i)

# the meta array braodcast style should retain the nested style information for
# whatever array type the meta array wraps
struct MetaArrayStyle{S} <: Broadcast.BroadcastStyle end
MetaArrayStyle(s::S) where S <: Broadcast.BroadcastStyle = MetaArrayStyle{S}()
Base.Broadcast.BroadcastStyle(::Type{<:MetaArray{A}}) where A = 
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
find_meta_style(x::MetaArray) = getmeta(x), getdata(x)

find_ms_helper(bc::Broadcast.Broadcasted,x::MetaArray) =
getmeta(x), Broadcast.broadcasted(bc.f,getdata(x))
find_ms_helper(bc::Broadcast.Broadcasted,x) = NoMetaData(), bc
function find_ms_helper(bc::Broadcast.Broadcasted,x::MetaArray,rest)
  meta, broadcasted = find_meta_style(rest)
  combine(getmeta(x),meta), Broadcast.broadcasted(bc.f,getdata(x),broadcasted)
end
function find_ms_helper(bc::Broadcast.Broadcasted,x,rest)
  meta, broadcasted = find_meta_style(rest)
  meta, Broadcast.broadcasted(bc.f,getdata(x),broadcasted)
end

# the wrapped arrays may define custom machinery for broadcasting:
# for in-place and out-of-place broadcasting extract the meta-data and use the
# same broadcast implementation the wrapped arrays would use to
# find the resulting data

# note: in-place broadcast cannot extract the meta data since the metadata
# fields are immutable.
function Base.copyto!(dest::AbstractArray, 
                      bc::Broadcast.Broadcasted{MetaArrayStyle{A}}) where A
  _, broadcasted = find_meta_style(bc)
  copyto!(dest, broadcasted)
end

function Base.copyto!(dest::MetaArray, bc::Broadcast.Broadcasted{Nothing})
  copyto!(getdata(dest),bc)
end

function Base.copy(bc::Broadcast.Broadcasted{MetaArrayStyle{A}}) where A
  meta, broadcasted = find_meta_style(bc)
  MetaArray(meta, copy(broadcasted))  
end

end # module
