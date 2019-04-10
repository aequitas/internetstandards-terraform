tf_version = 0.11.12
tf_plugin_transip_version = 0.0.2

tf = .bin/terraform
external_plugins = transip

setup: | .terraform/

plan apply destroy: | setup
	${tf} $@

.terraform/: | ${tf} ${external_plugins}
	${tf} init

${tf}:
	mkdir -p .bin/
	curl -s https://releases.hashicorp.com/terraform/${tf_version}/terraform_${tf_version}_darwin_amd64.zip | bsdtar -x -C .bin/ -f -

transip: .terraform/plugins/darwin_amd64/terraform-provider-transip_v${tf_plugin_transip_version}
.terraform/plugins/darwin_amd64/terraform-provider-transip_v${tf_plugin_transip_version}:
	mkdir -p ${@D}
	curl -sSL https://github.com/aequitas/terraform-provider-transip/releases/download/${tf_plugin_transip_version}/terraform-provider-transip_${tf_plugin_transip_version}_darwin_amd64.tgz | tar -zx -C ${@D} -f -

clean:
	rm -rf .terraform/ .bin/
