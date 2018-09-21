using Test
using MetaArrays

@testset "MetaArrays" begin
  @testset "MetaArray handles standard array operations" begin
    data = collect(1:10)
    x = meta(data,val=1)

    @test x[1] == data[1]
    @test (x[1] = 2; x[1] == 2)
    @test size(x) == size(data)
    @test similar(x) isa MetaArray
    @test x[1:5] == data[1:5]
    @test (x[1:5] .= 1; sum(x[1:5]) == 5)
    @test x .+ (1:10) == data .+ (1:10)
    @test (.-x) isa MetaArray
  end

  @testset "MetaArray preserves metadata over array operations" begin
    data = collect(1:10)
    x = meta(data,val=1)

    @test x.meta == (val=1,)
    @test x[1:5].meta == x.meta
    @test x[:].meta == x.meta
    @test (x .+ (1:10)).meta == x.meta
    @test (x .+= (1:10); x.meta == (val=1,))
    @test similar(x).meta == x.meta
    @test (.-x).meta == (val=1,)
  end

  @testset "MetaArray properly merges metadata" begin
    x = meta(collect(1:10),val=1)
    y = meta(collect(2:11),string="string")
    @test (x.+y).meta.val == 1
    @test (x.+y).meta.string == "string"

    x = meta(collect(1:10),val=1)
    y = meta(collect(1:10),val=2)
    @test_throws ErrorException x.+y

    x = meta(collect(1:10),val=(joe=2,bob=3))
    y = meta(collect(1:10),val=(bill=4,))
    @test (x.+y).meta.val == (joe=2,bob=3,bill=4)
  end

  @testset "MetaArray preseves broadcast specialization" begin
    x = meta(1:10,val=1)
    @test (x .+ 4) isa MetaArray{<:AbstractRange}
    @test (x .+ 4) == [xi+4 for xi in x]
    @test (.-x) isa MetaArray{<:AbstractRange}
    @test .-x == [-xi for xi in x]
  end
end
