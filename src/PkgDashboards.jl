module PkgDashboards

using Pkg, PrettyTables, Weave, InteractiveUtils, Markdown

export dashboard, pkgdashboard


struct DashBoard
    markdowntable
    header
end

function markdownstring(db)
    io = IOBuffer()
    pretty_table(io, db.markdowntable, db.header, backend=:text, tf=markdown)
    md = String(take!(io))
end


function Base.show(io::IO, ::MIME"text/plain", db::DashBoard)
    pretty_table(io, db.markdowntable, db.header, backend=:text)
end

function Base.show(io::IO, m::MIME"text/markdown", db::DashBoard)
    md = markdownstring(db)
    MD = Markdown.parse(md)
    show(io,m,MD)
end

function Base.show(io::IO, m::MIME"text/html", db::DashBoard)
    md = markdownstring(db)
    MD = Markdown.parse(md)
    write(io, html(MD))
end


function getuser(ctx, uuid::Pkg.Types.UUID)
    urls = String[]
    for path = Pkg.Types.registered_paths(ctx, uuid)
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
dashboard(target_users; output=:markdown, autoopen=false, stargazers=false, githubci=false, stars=true, activity=false)

Create a dashboard with all your badges!

### Arguments:
- `target_users`: a string or a vector of strings with github usernames or org names
- `output`: `:markdown` or `:html`
- `autoopen`: indicate whether or not the result is opened in editor or browser
- `githubci`: Also add a Badge for github CI
- `activity`: display number of commits per month
- `stars`: Add github star badge
- `stargazers`: include a plot with github stars over time

See also [`pkgdashboard`](@ref)
"""
function dashboard(target_users; kwargs...)
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
                entry = create_entry(user, name, url; kwargs...)
                push!(markdownpage, entry)
            end
        end
    end
    tab = table(markdownpage; kwargs...)
    write_output(tab; kwargs...)
    tab
end


"""
    pkgdashboard(packages; kwargs...)

Same as [`dashboard`](@ref) but accepts a list of package names instead.
"""
function pkgdashboard(packages; kwargs...)
    packages isa String && (packages = [packages])

    reg = Pkg.Types.collect_registries()[1]
    data = Pkg.Types.read_registry(joinpath(reg.path, "Registry.toml"))
    ctx = Pkg.Types.Context()

    markdownpage = []
    for (uuid, pkginfo) in data["packages"]
        name = pkginfo["name"]
        name ∈ packages || continue
        spec = PackageSpec(uuid=uuid)
        Uuid = Pkg.Types.UUID(uuid)
        users = getuser(ctx, Uuid)
        for (user,url) in users
            entry = create_entry(user, name, url; kwargs...)
            push!(markdownpage, entry)
        end
    end
    tab = table(markdownpage)
    write_output(tab; kwargs...)
    tab
end


function create_entry(user, name, url; output = :markdown, autoopen=false, stargazers=false, githubci=false, stars=true, activity=false)
    entry = ["[$(user)/$(name)]($(url))",
    "[![Build Status](https://travis-ci.org/$(user)/$(name).jl.svg?branch=master)](https://travis-ci.org/$(user)/$(name).jl)",
    "[![PkgEval](https://juliaci.github.io/NanosoldierReports/pkgeval_badges/$(first(name))/$(name).svg)](https://juliaci.github.io/NanosoldierReports/pkgeval_badges/$(first(name))/$(name).html)",
    "[![codecov](https://codecov.io/gh/$(user)/$(name).jl/branch/master/graph/badge.svg)](https://codecov.io/gh/$(user)/$(name).jl)"]
    if stars
        push!(entry, "[![Stars](https://img.shields.io/github/stars/$(user)/$(name).jl.svg)](https://github.com/$(user)/$(name).jl/stargazers)")
    end
    if githubci
        push!(entry, "[![Build Status](https://github.com/$(user)/$(name).jl/workflows/CI/badge.svg)](https://github.com/$(user)/$(name).jl/actions)")
    end
    if activity
        push!(entry, "[![activity](https://img.shields.io/github/commit-activity/m/$(user)/$(name).jl)](https://github.com/$(user)/$(name).jl/pulse)")
    end
    if stargazers
        push!(entry, "[![Stargazers over time](https://starchart.cc/$(user)/$(name).jl.svg)](https://starchart.cc/$(user)/$(name).jl)")
    end


    entry
end

function table(markdownpage; kwargs...)
    if length(markdownpage) == 1
        markdowntable = copy(reshape(markdownpage[1], 1, :))
    else
        markdowntable = copy(permutedims(reduce(hcat, markdownpage), (2,1)))
    end
    I = sortperm(markdowntable[:,1])
    markdowntable = markdowntable[I,:]
    header = ["URL", "Build status", "PkgEval", "CodeCov"]
    get(kwargs, :stars, true) && push!(header, "Github stars")
    get(kwargs, :githubci, false) && push!(header, "Github CI")
    get(kwargs, :activity, false) && push!(header, "Commit activity")
    get(kwargs, :stargazers, false) && push!(header, "stargazers")
    DashBoard(markdowntable, header)
end


function write_output(db::DashBoard; kwargs...)

    path = mktempdir()
    markdownpath = joinpath(path, "dashboard.md")
    open(markdownpath, "w") do io
        pretty_table(io, db.markdowntable, db.header, backend=:text, tf=tf_markdown)
    end

    if get(kwargs, :output, :markdown) == :html
        htmlpath = weave(markdownpath, doctype = "md2html")
        if get(kwargs, :autoopen, false)
            @async edit(htmlpath)
            @async run(`sensible-browser $htmlpath`)
        end
    else
        @info "Wrote markdown to $markdownpath"
        get(kwargs, :autoopen, false) && edit(markdownpath)
    end
end

end # module
