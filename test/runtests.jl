using Test
using MetaArrays

struct TestMerge
  val::Int
end
MetaArrays.metamerge(x::TestMerge,y::TestMerge) = TestMerge(x.val + y.val)

struct TestMergeFail
  val::Int
end

# TODO: add some more robust tests of broadcast machinery
# (greater variety of arguments, with more call variants
# and then check for test coverage

@testset "MetaArrays" begin

  @testset "MetaArray handles standard array operations" begin
    data = collect(1:10)
    x = meta(data,val=1)
    y = meta(collect(1:10),val=1)

    @test (x.^2) == (1:10).^2
    @test x[1] == data[1]
    @test size(x) == size(data)
    @test similar(x) isa MetaArray
    @test x[1:5] == data[1:5]
    @test (y[1:5] .= 1; sum(y[1:5]) == 5)
    @test (y[1] = 2; y[1] == 2)
    @test x .+ (1:10) == data .+ (1:10)
    @test (.-x) isa MetaArray
    @test collect(1:10) .+ x .+ collect(11:20) == (13:3:40)
    @test broadcast(+,collect(1:10),x,collect(11:20)) == (13:3:40)
    @test (1:10) .+ meta(1:10,val=1) .+ (11:20) isa MetaArray
  end

  @testset "MetaArray preserves metadata over array operations" begin
    data = collect(1:10)
    x = meta(data,val=1)

    @test x.val == 1
    @test x[1:5].val == x.val
    @test x[:].val == x.val
    @test (x .+ (1:10)).val == x.val
    @test (x .+= (1:10); x.val == 1)
    @test (broadcast(+,x,1:10).val == x.val)
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
    @test broadcast(+,x,y).val == TestMerge(3)

    x = meta(collect(1:10),val=(joe=2,bob=3))
    y = meta(collect(1:10),val=(bill=4,))
    @test (x.+y).val == (joe=2,bob=3,bill=4)
  end

  @testset "MetaArray preserves broadcast specialization" begin
    x = meta(1:10,val=1)
    @test (x .+ 4) isa MetaArray{<:AbstractRange}
    @test (x .+ 4) == [xi+4 for xi in x]
    @test (.-x) isa MetaArray{<:AbstractRange}
    @test (1:10) .+ meta(1:10,val=1) .+ (11:20) isa MetaArray{<:AbstractRange}
    @test .-x == [-xi for xi in x]
  end

  @testset "MetaArray allows custom metadata type" begin
    x = MetaArray(TestMerge(2),1:10)
    y = MetaArray(TestMerge(3),1:10)
    k = MetaArray(TestMergeFail(1),1:10)
    h = MetaArray(TestMergeFail(1),1:10)
    m = MetaArray(TestMergeFail(2),1:10)

    z = x.+y
    @test x == 1:10
    @test (x.+y) == ((1:10) .+ (1:10))
    @test (x.+y).val == 5
    @test (h.+k).val == 1
    @test_throws ErrorException h.+m
  end

end
