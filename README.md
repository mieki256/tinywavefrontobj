tinywavefrontobj
================

Wavefront形式(.obj)の3Dモデルデータを読み込んでテキスト出力。

Description
-----------

Wavefront形式(.obj)の3Dモデルデータファイルを読み込んで、Rubyから使いやすい形式でテキスト出力します。

全属性に対応していませんが、3D描画関係の実験用モデルデータを用意する、ぐらいのことには使えるんじゃないかなと…。

Usage
-----

### Rubyソース内に書ける形で出力

    ruby tinywavefrontobj.rb sampledata/cube_tri_tex.obj

### jsonもしくはyamlで出力

    ruby tinywavefrontobj.rb sampledata/cube_tri_tex.obj --json

    ruby tinywavefrontobj.rb sampledata/cube_tri_tex.obj --yaml

### 使用可能なオプション

    Usage : ruby tinywavefrontobj.rb INFILE.obj [options]
            --no-index                   not use vertex index
        -x, --xflip                      x flip
        -y, --yflip                      y flip
        -z, --zflip                      z flip
            --[no-]vflip                 v flip
        -c, --color                      add diffuse color array
            --hexcolor                   color code 0xAARRGGBB
            --json                       output json format
            --yaml                       output YAML format
            --no-varray                  not use vertex array
            --debug                      dump .obj information

### 出力したjsonを読み込んで利用

    require 'json'
    ...
    vertex_array = nil
    normal_array = nil
    uv_array     = nil
    face_array   = nil
    File.open("sample.json") { |file|
      hash = JSON.load(file)
      vertex_array = hash["vertex"]
      normal_array = hash["normal"] if hash.key?("normal")
      uv_array     = hash["uv"] if hash.key?("uv")
      face_array   = hash["face"]
    }
    ...
    puts "use texture" if uv_array
    puts "use normal" if normal_array

### Rubyソース内で利用して頂点配列等を取得

    require_relative 'tinywavefrontobj'
    ...
    o = TinyWaveFrontObj.new("sample.obj")
    vertex_array = o.get_vertex_array
    normal_array = o.get_normal_array
    uv_array     = o.get_uv_array
    face_array   = o.get_face_array
    ...
    puts "use texture" if o.use_uv
    puts "use normal" if o.use_normal

Testing environment
-------------------

Ruby 2.2.6 p396 mingw32 + Windows10 x64

Licence
-------

CCo / Public Domain

Author
------

mieki256
