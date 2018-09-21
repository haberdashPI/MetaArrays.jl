using Test
using MetaArrays

struct TestMerge
  val::Int
end
MetaArrays.metamerge(x::TestMerge,y::TestMerge) = TestMerge(x.val + y.val)

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

    @test x.val == 1
    @test x[1:5].val == x.val
    @test x[:].val == x.val
    @test (x .+ (1:10)).val == x.val
    @test (x .+= (1:10); x.val == 1)
    @test similar(x).val == x.val
    @test (.-x).val == 1
  end

  @testset "MetaArray properly merges metadata" begin
    x = meta(collect(1:10),val=1)
    y = meta(collect(2:11),string="string")
    @test (x.+y).val == 1
    @test (x.+y).string == "string"

    x = meta(collect(1:10),val=1)
    y = meta(collect(1:10),val=2)
    @test_throws ErrorException x.+y

    x = meta(collect(1:10),val=TestMerge(1))
    y = meta(collect(1:10),val=TestMerge(2))
    @test (x.+y).val == TestMerge(3)

    x = meta(collect(1:10),val=(joe=2,bob=3))
    y = meta(collect(1:10),val=(bill=4,))
    @test (x.+y).val == (joe=2,bob=3,bill=4)
  end

  @testset "MetaArray preseves broadcast specialization" begin
    x = meta(1:10,val=1)
    @test (x .+ 4) isa MetaArray{<:AbstractRange}
    @test (x .+ 4) == [xi+4 for xi in x]
    @test (.-x) isa MetaArray{<:AbstractRange}
    @test .-x == [-xi for xi in x]
  end
end
