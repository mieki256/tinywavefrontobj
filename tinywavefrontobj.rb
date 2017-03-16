#!ruby -Ku
# -*- mode: ruby; coding: utf-8 -*-
# Last updated: <2017/03/15 21:01:42 +0900>
#
# wavefront(.obj) read, parse and dump
#
# usage :
#   ruby wavefrontobj.rb INFILE.obj [options]
#   ruby wavefrontobj.rb --help
#
# testing environment : Ruby 2.2.6 p396 mingw32
# License : CC0 / Public Domain

Version = "1.0.0"

require 'pp'
require 'json'
require 'yaml'

# wavefront(.obj) read, parse and dump class
class TinyWaveFrontObj

  # @return [String] .obj file path
  attr_reader :objpath

  # @return [String] Directory where .obj is stored
  attr_reader :objdir

  # @return [String] .mtl filename (material file)
  attr_reader :material_filename

  # @return [Array<Array>] vertex (x, y, z, w)
  attr_reader :vertexs

  # @return [Array<Array>] uv (u, v, w)
  attr_reader :uvs

  # @return [Array<Array>] normal (x, y, z)
  attr_reader :normals

  # @return [Array<Array>] vp ( u or u, v or u, v, w)
  attr_reader :vps

  # @return [Hash<Array>] face
  attr_reader :faces

  # @return [Hash] material
  attr_reader :mtls

  # @return [Array] textures
  attr_reader :texs

  # @return [Hash] vertex array data
  attr_reader :vertex_array_data

  # @return [true, false] use vertex
  attr_reader :use_vertex

  # @return [true, false] use normal
  attr_reader :use_normal

  # @return [true, false] use uv (texture)
  attr_reader :use_uv

  # @return [true, false] use index (vertex index)
  attr_accessor :use_index

  # initialize
  #
  # @param objpath [String] .obj path
  # @param use_varray [true, false] use vertex array
  # @param use_index [true, false] use vertex index
  def initialize(objpath, use_varray = true, use_index = true)
    @use_varray = use_varray
    @use_index = use_index
    @objpath = File.expand_path(objpath)

    @objdir = File.dirname(@objpath)
    @mtlname = ""
    @vertexs = []
    @uvs = []
    @normals = []
    @vps = []
    @faces = {}
    @mtls = {}
    @texs = []
    @vertex_array_data = {}
    @use_vertex = false
    @use_normal = false
    @use_uv = false

    read_geometry(@objpath)

    @mtlpath = File.join(@objdir, @mtlname)
    read_material(@mtlpath)
    @texs = get_texture_list

    if use_varray
      make_varray_data
    end
  end

  def read_geometry(objpath)
    dbg = false
    mat = "none"
    smooth = false
    objgroup = ""
    File.open(objpath) do |file|
      file.each_line do |l|
        next if l =~ /^#/
        next if l =~ /^$/

        s = l.split(" ")
        case s[0]
        when "mtllib"
          @mtlname = s[1]
          puts ".mtl = #{@mtlname}" if dbg
        when "o"
          objgroup = s[1]
          puts "objgroup #{objgroup}" if dbg
        when "v"
          # vertex
          if s.size == 4
            x, y, z, w = s[1].to_f, s[2].to_f, s[3].to_f, 1.0
            @vertexs.push([x, y, z, w])
          elsif s.size == 5
            x, y, z, w = s[1].to_f, s[2].to_f, s[3].to_f, s[4].to_f
            @vertexs.push([x, y, z, w])
          end
        when "vt"
          # texture u v
          if s.size == 3
            u, v, w = s[1].to_f, s[2].to_f, 0.0
            @uvs.push([u, v, w])
          elsif s.size == 4
            u, v, w = s[1].to_f, s[2].to_f, s[3].to_f
            @uvs.push([u, v, w])
          end
        when "vn"
          # normal
          x, y, z = s[1].to_f, s[2].to_f, s[3].to_f
          @normals.push([x, y, z])
        when "vp"
          if s.size == 2
            u = s[1].to_f
            @vps.push([u])
          elsif s.size == 3
            u, v = s[1].to_f, s[2].to_f
            @vps.push([u, v])
          elsif s.size == 4
            u, v, w = s[1].to_f, s[2].to_f, s[3].to_f
            @vps.push([u, v, w])
          end
        when "usemtl"
          # use material
          mat = s[1]
          puts "material #{mat}" if dbg
          unless @faces.key?(mat)
            @faces[mat] = []
          end
        when "s"
          # Smooth
          if s[1] == "off"
            smooth = false
          else
            smooth = true
          end
          puts "smooth #{smooth}" if dbg
        when "f"
          # face
          finfo = []
          s.each do |n|
            if n =~ %r|^(\d+)/(\d+)/(\d+)$|
              # vertex, uv, normal
              vi, vti, vni = ($1.to_i - 1), ($2.to_i - 1), ($3.to_i - 1)
              finfo.push([vi, vti, vni])
              @use_vertex = true
              @use_uv = true
              @use_normal = true
            elsif n =~ %r|^(\d+)//(\d+)$|
              # vertex, normal
              vi, vti, vni = ($1.to_i - 1), nil, ($2.to_i - 1)
              finfo.push([vi, vti, vni])
              @use_vertex = true
              @use_normal = true
            elsif n =~ %r|^(\d+)/(\d+)$|
              # vertex, uv
              vi, vti, vni = ($1.to_i - 1), ($2.to_i - 1), nil
              finfo.push([vi, vti, vni])
              @use_vertex = true
              @use_uv = true
            elsif n =~ %r|^(\d+)$|
              # vertex only
              vi, vti, vni = ($1.to_i - 1), nil, nil
              finfo.push([vi, vti, vni])
              @use_vertex = true
            end
          end
          unless finfo.empty?
            dt = { :mat => mat, :smooth => smooth, :vertexs => finfo }
            @faces[mat].push(dt)
          end
        end
      end
    end
  end

  def read_material(mtlpath)
    mtlname = ""
    File.open(mtlpath) do |f|
      f.each_line do |l|
        next if l=~ /^#/
        next if l=~ /^$/

        s = l.split(" ")
        case s[0]
        when "newmtl"
          mtlname = s[1]
          @mtls[mtlname] = {}
        when "Ka"
          # Ambient
          r, g, b = s[1].to_f, s[2].to_f, s[3].to_f
          @mtls[mtlname][:ambient] = [r, g, b, 1.0]
        when "Kd"
          # Diffuse
          r, g, b = s[1].to_f, s[2].to_f, s[3].to_f
          @mtls[mtlname][:diffuse] = [r, g, b, 1.0]
        when "Ks"
          # Specular
          r, g, b = s[1].to_f, s[2].to_f, s[3].to_f
          @mtls[mtlname][:specular] = [r, g, b, 1.0]
        when "Ns"
          # Shininess
          @mtls[mtlname][:shininess] = s[1].to_f
        when "Ke"
          # Emission ?
          r, g, b = s[1].to_f, s[2].to_f, s[3].to_f
          @mtls[mtlname][:emission] = [r, g, b, 1.0]
        when "Ni"
          # Optical density
          @mtls[mtlname][:optical_density] = s[1].to_f
        when "d"
          # Dissolve
          @mtls[mtlname][:dissolve] = s[1].to_f
        when "illum"
          # Lighting model
          @mtls[mtlname][:illum] = s[1].to_i
        when "map_Ka"
          # Ambient texture
          @mtls[mtlname][:ambient_tex] = s[1]
        when "map_Kd"
          # Diffuse texture
          @mtls[mtlname][:diffuse_tex] = s[1]
        when "map_Ks"
          # Specular texture
          @mtls[mtlname][:specular_tex] = s[1]
        when "map_Ns"
          # Specular highlight texture
          @mtls[mtlname][:specular_high_tex] = s[1]
        when "map_d"
          # Dissolve texture
          @mtls[mtlname][:dissolve_tex] = s[1]
        when "map_bump"
          # Bump mapping texture
          @mtls[mtlname][:map_bump_tex] = s[1]
        when "bump"
          # Bump mapping texture
          @mtls[mtlname][:bump_tex] = s[1]
        when "disp"
          # Displacement texture
          @mtls[mtlname][:displacement_tex] = s[1]
        when "decal"
          # Stencil decal texture
          @mtls[mtlname][:decal_tex] = s[1]
        end
      end
    end
  end

  # get texture list
  # @return [Array<String>] texture name
  def get_texture_list
    lst = {}
    @mtls.each_value do |mat|
      [
        :ambient_tex,
        :diffuse_tex,
        :specular_tex,
        :specular_high_tex,
        :dissolve_tex,
        :map_bump_tex,
        :bump_tex,
        :displacement_tex,
        :decal_tex
      ].each do |k|
        lst[mat[k]] = 1 if mat.key?(k)
      end
    end
    return lst.keys
  end

  # make vertex array data
  #
  # @param vflip [true, false] flip the v of u, v
  # @param face [true, false] create data and overwrite
  def make_varray_data(vflip = true, force = false)
    if @vertex_array_data.empty? or force
      if @use_index
        make_varray_with_index(vflip)
      else
        make_varray_not_with_index(vflip)
      end
    end
  end

  # make vertex array not with vertex index
  #
  # @param vflip [true, false] flip the v of u, v
  def make_varray_not_with_index(vflip = true)
    vertexs = []
    normals = []
    uvs = []

    @faces.each do |mtlname, value|
      value.each do |face|
        finfo = []
        face[:vertexs].each do |vi, vti, vni|
          x, y, z, _ = @vertexs[vi]
          vertexs.push([x, y, z])

          if @use_uv
            u, v = 0.0, 0.0
            if vti
              u, v, _ = @uvs[vti]
              v = 1.0 - v if vflip
            end
            uvs.push([u, v])
          end

          if @use_normal
            nx, ny, nz = 0.0, 0.0, 0.0
            nx, ny, nz, _ = @normals[vni] if vni
            normals.push([nx, ny, nz])
          end
        end
      end
    end

    @vertex_array_data = {
      :vertex => vertexs,
      :normal => normals,
      :uv => uvs,
    }
  end

  # make vertex array with vertex index
  #
  # @param vflip [true, false] flip the v of u, v
  def make_varray_with_index(vflip = true)
    vertexs = []
    normals = []
    uvs = []
    faces = []

    cnt = 0
    @faces.each do |mtlname, value|
      value.each do |face|
        finfo = []
        face[:vertexs].each do |v|
          vi, vti, vni = v
          x, y, z = 0.0, 0.0, 0.0
          nx, ny, nz = 0.0, 0.0, 0.0
          u, v = 0.0, 0.0

          x, y, z, _ = @vertexs[vi] if vi
          nx, ny, nz, _ = @normals[vni] if vni

          if vti
            u, v, _ = @uvs[vti]
            v = 1.0 - v if vflip
          end

          xyz = [x, y, z]
          uv = [u, v]
          nxyz = [nx, ny, nz]

          find_idx = nil
          if vertexs.include?(xyz)
            idx = vertexs.index(xyz)
            if uvs[idx] == uv and normals[idx] == nxyz
              find_idx = idx
            end
          end

          if find_idx != nil
            finfo.push(find_idx)
          else
            vertexs.push(xyz)
            uvs.push(uv)
            normals.push(nxyz)
            finfo.push(cnt)
            cnt += 1
          end
        end
        faces.push(finfo)
      end
    end

    @vertex_array_data = {
      :vertex => vertexs,
      :normal => normals,
      :uv => uvs,
      :face => faces,
    }
  end

  # get vertex array
  # @return [Array<Float>] vertex array
  def get_vertex_array
    return nil unless @use_vertex
    make_varray_data
    return @vertex_array_data[:vertex].flatten
  end

  # get normal array
  # @return [Array<Float>] normal array
  def get_normal_array
    return nil unless @use_normal
    make_varray_data
    return @vertex_array_data[:normal].flatten
  end

  # get uv array
  # @return [Array<Float>] uv array
  def get_uv_array
    return nil unless @use_uv
    make_varray_data
    return @vertex_array_data[:uv].flatten
  end

  # get face (vertex index) array
  # @return [Array<Integer>] face (vertex index) array
  def get_face_array
    return nil unless @use_index
    make_varray_data
    return @vertex_array_data[:face].flatten
  end

  def dump_info_size
    puts "\# vertex = #{@vertexs.size}"
    puts "\# uv     = #{@uvs.size}"
    puts "\# normal = #{@normals.size}"

    cnt = 0
    @faces.each { |k, v| cnt += v.size }
    puts "\# face   = #{cnt}"
    puts "\# material = #{@faces.size}"
    puts
  end

  def dump_faces
    puts "\# " + ('-' * 40)
    puts "\# Face"
    puts
    @faces.each do |key, value|
      puts "material : #{key}"
      value.each_with_index do |f, i|
        puts "face #{i} : "
        pp f
      end
    end
    puts
  end

  def dump_mtl
    puts "\# " + ('-' * 40)
    puts "\# Material"
    puts
    @mtls.each do |key, value|
      puts "#{key} :"
      pp value
    end
    puts
  end

  def dump_texs
    puts "\# " + ('-' * 40)
    puts "\# Texture image list"
    puts
    @texs.each { |tn| puts tn }
    puts
  end

  def dump_vertex_array(use_format = "raw")
    make_varray_data
    case use_format
    when "json"
      puts get_vertex_array_json
    when "yaml"
      puts get_vertex_array_yaml
    else
      puts get_vertex_array_raw
    end
  end

  def get_vertex_array_json(pretty = false)
    dt = { "vertex" => get_vertex_array }
    dt["normal"] = get_normal_array if @use_normal
    dt["uv"] = get_uv_array if @use_uv
    dt["face"] = get_face_array if @use_index
    s = (pretty)? JSON.pretty_generate(dt) : JSON.generate(dt)
    return s
  end

  def get_vertex_array_yaml
    dt = { "vertex" => get_vertex_array }
    dt["normal"] = get_normal_array if @use_normal
    dt["uv"] = get_uv_array if @use_uv
    dt["face"] = get_face_array if @use_index
    return dt.to_yaml
  end

  def get_vertex_array_raw
    s = []
    s.push("@vertexes = [")
    @vertex_array_data[:vertex].each_with_index do |xyz, i|
      x, y, z = xyz
      s.push("  #{x}, #{y}, #{z},  \# #{i}")
    end
    s.push("]")
    s.push("")

    if @use_normal
      s.push("@normals = [")
      @vertex_array_data[:normal].each_with_index do |nxyz, i|
        nx, ny, nz = nxyz
        s.push("  #{nx}, #{ny}, #{nz},  \# #{i}")
      end
      s.push("]")
      s.push("")
    end

    if @use_uv
      s.push("@uvs = [")
      @vertex_array_data[:uv].each_with_index do |uv, i|
        u, v = uv
        s.push("  #{u}, #{v},  \# #{i}")
      end
      s.push("]")
      s.push("")
    end

    if @use_index
      s.push("@faces = [")
      @vertex_array_data[:face].each_with_index do |finfo, i|
        l = ""
        finfo.each { |idx| l += "#{idx}, " }
        l.strip!
        s.push("  #{l}  \# #{i}")
      end
      s.push("]")
    end

    return s.join("\n")
  end

end

# ----------------------------------------
if $0 == __FILE__

  require 'optparse'

  opts = {
    :varray => true,
    :index => true,
    :json => false,
    :yaml => false,
    :debug => false
  }
  OptionParser.new do |opt|
    opt.banner = "Usage : ruby #{$0} INFILE.obj [options]"
    opt.on("--no-varray", "vertex array disable") { |v| opts[:varray] = v }
    opt.on("--no-index", "vertex index disable") { |v| opts[:index] = v }
    opt.on("--json", "use json format") { |v| opts[:json] = v }
    opt.on("--yaml", "use YAML format") { |v| opts[:yaml] = v }
    opt.on("--debug", "dump .obj information") { |v| opts[:debug] = v }

    begin
      opt.parse!(ARGV)
    rescue
      puts "Invalid option. \n#{opt}"
      exit 1
    end

    unless ARGV.empty?
      opts[:infile] = ARGV[0] if ARGV[0] =~ /\.obj$/i
    end

    unless opts.key?(:infile)
      puts "Not found .obj file. \n#{opt}"
      exit 1
    end
  end

  o = TinyWaveFrontObj.new(opts[:infile], opts[:varray], opts[:index])

  if opts[:debug]
    o.dump_info_size
    o.dump_faces
    o.dump_mtl
    o.dump_texs
  else
    if opts[:varray]
      fmt = "raw"
      fmt = "json" if opts[:json]
      fmt = "yaml" if opts[:yaml]
      o.dump_vertex_array(fmt)
    end
  end
end
