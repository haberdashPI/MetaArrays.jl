using Test
using MetaArrays

@testset "MetaArrays" begin
  @testset "MetaArray handles standard array operations" begin
    data = collect(1:10)
    x = meta((val=1,),data)

    @test x[1] == data[1]
    @test (x[1] = 2; x[1] == 2)
    @test size(x) == size(data)
    @test similar(x) isa MetaArray
    @test x[1:5] == data[1:5]
    @test (x[1:5] .= 1; sum(x[1:5]) == 5)
    @test x .+ (1:10) == data .+ (1:10)
  end

  @testset "MetaArray takes keywords" begin
    x = meta(1:10,val = 1)
    @test x.meta.val == 1
  end

  @testset "MetaArray preserves metadata over array operations" begin
    data = collect(1:10)
    x = meta((val=1,),data)

    @test x.meta == (val=1,)
    @test x[1:5].meta == x.meta
    @test x[:].meta == x.meta
    @test (x .+ (1:10)).meta == x.meta
    @test (x .+= (1:10); x.meta == (val=1,))
    @test similar(x).meta == x.meta
  end

  @testset "MetaArray preseves broadcast specialization" begin
    x = meta((val=1,),1:10)
    @test (x .+ 4) isa MetaArray{<:Any,<:Range}
  end
end
