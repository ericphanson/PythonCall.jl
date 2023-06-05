@testitem "pywith" begin
    @testset "no error" begin
        tdir = pyimport("tempfile").TemporaryDirectory()
        tname = PythonCall.PythonCall_Base.pystr_asstring(tdir.name)
        @test isdir(tname)
        pywith(tdir) do name
            @test PythonCall.PythonCall_Base.pystr_asstring(name) == tname
        end
        @test !isdir(tname)
    end
    @testset "error" begin
        tdir = pyimport("tempfile").TemporaryDirectory()
        tname = PythonCall.PythonCall_Base.pystr_asstring(tdir.name)
        @test isdir(tname)
        @test_throws PyException pywith(name -> name.invalid_attr, tdir)
        @test !isdir(tname)
    end
end
