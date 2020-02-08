module PkgDashboards

using Pkg, PrettyTables, Weave, InteractiveUtils

export dashboard

function getuser(ctx, uuid::Pkg.Types.UUID)
    urls = String[]
    for path = Pkg.Types.registered_paths(ctx.env, uuid)
        info = Pkg.Types.parse_toml(path, "Package.toml")
        repo = info["repo"]
        repo in urls || push!(urls, repo)
    end
    users = zip(getuser.(urls), urls)
end

function getuser(url::String)
    m = match(r"github\.com/(.+?)/", url)
    m === nothing ? nothing : string(m.captures[1])
end


"""
    dashboard(target_users, output=:markdown; autoopen=true, stargazers=false, githubci=false)

Create a dashboard with all your badges!

### Arguments:
- `target_users`: a string or a vector of strings with github usernames or org names
- `output`: `:markdown` or `:html`
- `autoopen`: indicate whether or not the result is opened in editor or browser
- `stargazers`: include a plot with github stars over time
- `githubci`: Also add a Badge for github CI
"""
function dashboard(target_users, output=:markdown; autoopen=true, stargazers=false, githubci=false)
    target_users isa String && (target_users = [target_users])

    reg = Pkg.Types.collect_registries()[1]
    data = Pkg.Types.read_registry(joinpath(reg.path, "Registry.toml"))
    ctx = Pkg.Types.Context()

    markdownpage = []
    for (uuid, pkginfo) in data["packages"]
        name = pkginfo["name"]
        spec = PackageSpec(uuid=uuid)
        Uuid = Pkg.Types.UUID(uuid)
        users = getuser(ctx, Uuid)
        for (user,url) in users
            if user ∈ target_users
                entry = ["[$(user)/$(name)]($(url))",
                "[![Build Status](https://travis-ci.org/$(user)/$(name).jl.svg?branch=master)](https://travis-ci.org/$(user)/$(name).jl)",
                "[![PkgEval](https://juliaci.github.io/NanosoldierReports/pkgeval_badges/$(first(name))/$(name).svg)](https://juliaci.github.io/NanosoldierReports/pkgeval_badges/report.html)",
                "[![codecov](https://codecov.io/gh/$(user)/$(name).jl/branch/master/graph/badge.svg)](https://codecov.io/gh/$(user)/$(name).jl)"]
                if stargazers
                    push!(entry, "[![Stargazers over time](https://starchart.cc/$(user)/$(name).jl.svg)](https://starchart.cc/$(user)/$(name).jl)")
                end
                if githubci
                    push!(entry, "[![Build Status](https://github.com/$(user)/$(name).jl/workflows/CI/badge.svg)](https://github.com/$(user)/$(name).jl/actions)")
                end

                push!(markdownpage, entry)
            end
        end
    end

    markdowntable = copy(permutedims(reduce(hcat, markdownpage), (2,1)))

    header = ["URL", "Build status", "PkgEval", "CodeCov"]
    stargazers && push!(header, "stargazers")
    githubci && push!(header, "Github CI")
    path = mktempdir()
    markdownpath = joinpath(path, "dashboard.md")
    open(markdownpath, "w") do io
        pretty_table(io, markdowntable, header, backend=:text, tf=markdown)
    end

    if output == :html
        htmlpath = weave(markdownpath, doctype = "md2html")
        if autoopen
            @async edit(htmlpath)
            @async run(`sensible-browser $htmlpath`)
        end
    else
        @info "Wrote markdown to $markdownpath"
        autoopen && edit(markdownpath)
    end
    nothing

end

end # module
