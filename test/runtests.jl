using PkgDashboards
using Test

@testset "PkgDashboards.jl" begin

    db = dashboard("mfalt", output=:markdown, autoopen=false)
    @test db isa PkgDashboards.DashBoard
    db = dashboard("mfalt", output=:html, autoopen=false)
    @testset "show" begin
        @info "Testing show"
        io = IOBuffer()
        for m in [MIME"text/plain",MIME"text/markdown",MIME"text/html"]
            @test_nowarn show(io, m(), db)
        end
    end

    @test_nowarn db = dashboard("mfalt", output=:markdown, autoopen=false, stargazers=true, activity=true, githubci=true)
    @testset "pkgdashboard" begin
        @info "Testing pkgdashboard"
        @test_nowarn db = pkgdashboard("Hyperopt", output=:markdown, autoopen=false)
    end
end
