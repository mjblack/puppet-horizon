require 'spec_helper'

describe 'horizon::wsgi::apache' do

  let :params do
    { 'fqdn'       => 'some.host.tld',
      'servername' => 'some.host.tld'
    }
  end

  let :pre_condition do
    "include apache\n" +
    "class { 'horizon': secret_key => 's3cr3t', configure_apache => false }"
  end

  let :fixtures_path do
    File.expand_path(File.join(__FILE__, '..', '..', 'fixtures'))
  end

  let :facts do
    { :concat_basedir => '/var/lib/puppet/concat',
      :fqdn           => 'some.host.tld'
    }
  end

  shared_examples 'apache for horizon' do

    context 'with default parameters' do
      it 'configures apache' do
        should contain_class('horizon::params')
        should contain_class('apache')
        should contain_class('apache::mod::wsgi')
        should contain_service('httpd').with_name(platforms_params[:http_service])
        should contain_file(platforms_params[:httpd_config_file])
        describe 'with default parameters' do
          it { should contain_package('horizon').with_ensure('present') }
          it { should contain_apache__vhost('horizon_vhost').with(
            'servername'           => 'some.host.tld',
            'port'                 => 80,
            'serveraliases'        => '*',
            'docroot'              => '/var/www/',
            'ssl'                  => 'false',
            'redirectmatch_status' => 'permanent',
            'redirectmatch_regexp' => "^/$ #{platforms_params[:root_url]}",
            'wsgi_script_aliases'  => { platforms_params[:root_url] => '/usr/share/openstack-dashboard/openstack_dashboard/wsgi/django.wsgi' }
            )}
          end
      end
    end

    context 'with ssl enabled' do
      before do
        params.merge!({
          :listen_ssl   => true,
          :ssl_redirect => true,
          :horizon_cert => '/etc/pki/tls/certs/httpd.crt',
          :horizon_key  => '/etc/pki/tls/private/httpd.key',
          :horizon_ca   => '/etc/pki/tls/certs/ca.crt',
        })
      end

      context 'with required parameters' do
        it 'configures apache for SSL' do
          should contain_class('apache::mod::ssl')
        end
        it { should contain_apache__vhost('horizon_ssl_vhost').with(
          'servername'             => 'some.host.tld',
          'serveraliases'          => '*',
          'port'                   => 443,
          'docroot'                => '/var/www/',
          'ssl'                    => 'true',
          'ssl_cert'               => '/etc/pki/tls/certs/httpd.crt',
          'ssl_key'                => '/etc/pki/tls/private/httpd.key',
          'ssl_ca'                 => '/etc/pki/tls/certs/ca.crt',
          'redirectmatch_status'   => 'permanent',
          'redirectmatch_regexp'   => "^/$ #{platforms_params[:root_url]}",
          'wsgi_script_aliases'    => { platforms_params[:root_url] => '/usr/share/openstack-dashboard/openstack_dashboard/wsgi/django.wsgi' }
        )}
  
        it { should contain_apache__vhost('horizon_vhost').with(
          'servername'           => 'some.host.tld',
          'serveraliases'        => '*',
          'port'                 => 80,
          'docroot'              => '/var/www/',
          'ssl'                  => 'false',
          'redirectmatch_status' => 'permanent',
          'redirectmatch_regexp' => '(.*) https://some.host.tld',
          'wsgi_script_aliases'  => { platforms_params[:root_url] => '/usr/share/openstack-dashboard/openstack_dashboard/wsgi/django.wsgi' }
        )}
      end

      context 'without required parameters' do

        context 'without horizon_ca parameter' do
          before { params.delete(:horizon_ca) }
          it_raises 'a Puppet::Error', /The horizon_ca parameter is required when listen_ssl is true/
        end

        context 'without horizon_cert parameter' do
          before { params.delete(:horizon_cert) }
          it_raises 'a Puppet::Error', /The horizon_cert parameter is required when listen_ssl is true/
        end

        context 'without horizon_key parameter' do
          before { params.delete(:horizon_key) }
          it_raises 'a Puppet::Error', /The horizon_key parameter is required when listen_ssl is true/
        end
      end
    end
  end

  context 'on RedHat platforms' do
    before do
      facts.merge!({
        :osfamily               => 'RedHat',
        :operatingsystemrelease => '6.0'
      })
    end

    let :platforms_params do
      { :http_service      => 'httpd',
        :httpd_config_file => '/etc/httpd/conf.d/openstack-dashboard.conf',
        :root_url          => '/dashboard' }
    end

    it_behaves_like 'apache for horizon'
  end

  context 'on Debian platforms' do
    before do
      facts.merge!({
        :osfamily               => 'Debian',
        :operatingsystemrelease => '6.0'
      })
    end

    let :platforms_params do
      { :http_service      => 'apache2',
        :httpd_config_file => '/etc/apache2/conf.d/openstack-dashboard.conf',
        :root_url          => '/horizon' }
    end

    it_behaves_like 'apache for horizon'
  end
end
