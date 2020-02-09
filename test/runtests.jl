using PkgDashboards
using Test

@testset "PkgDashboards.jl" begin

    db = dashboard("mfalt", output=:markdown, autoopen=false)
    @test db isa PkgDashboards.DashBoard
    db = dashboard("mfalt", output=:html, autoopen=false)
    io = IOBuffer()
    for m in [MIME"text/plain",MIME"text/markdown",MIME"text/html"]
        @test_nowarn show(io, m(), db)
    end

    @test_nowarn db = dashboard("mfalt", output=:markdown, autoopen=true, stargazers=true, activity=true, githubci=true)

    @test_nowarn db = pkgdashboard("Hyperopt", output=:markdown, autoopen=false)
end
