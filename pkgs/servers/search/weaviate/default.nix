{ lib
, buildGoModule
, fetchFromGitHub
}:

buildGoModule rec {
  pname = "weaviate";
  version = "1.19.8";

  src = fetchFromGitHub {
    owner = "weaviate";
    repo = "weaviate";
    rev = "v${version}";
    hash = "sha256-rSv6ERVReWMt05C70a8i+hgTF2JGvcSkydex/2Vp+80=";
  };

  vendorHash = "sha256-27YbjTtFaD5nMkcTXeAR/vZPWgG5qRvdnoNv6S7/SOI=";

  subPackages = [ "cmd/weaviate-server" ];

  ldflags = [ "-w" "-extldflags" "-static" ];

  postInstall = ''
    ln -s $out/bin/weaviate-server $out/bin/weaviate
  '';

  meta = with lib; {
    description = "The ML-first vector search engine";
    homepage = "https://github.com/semi-technologies/weaviate";
    license = licenses.bsd3;
    maintainers = with maintainers; [ dit7ya ];
  };
}
