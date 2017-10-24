require 'spec_helper'

describe 'prometheus::daemon' do
  let :title do
    'smurf_exporter'
  end

  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) do
        facts
      end

      let :pre_condition do
        'include ::prometheus::params'
      end

      [
        {
          version:           '1.2.3',
          real_download_url: 'https://github.com/prometheus/smurf_exporter/releases/v1.2.3/smurf_exporter-1.2.3.any.tar.gz',
          notify_service:    'Service[smurf_exporter]',
          user:              'smurf_user',
          group:             'smurf_group'
        }
      ].each do |parameters|
        context "with parameters #{parameters}" do
          let(:params) do
            parameters
          end

          prom_os = facts[:kernel].downcase
          prom_arch = facts[:architecture] == 'i386' ? '386' : 'amd64'

          it {
            is_expected.to contain_archive("/tmp/smurf_exporter-#{parameters[:version]}.tar.gz").with(
              'ensure'          => 'present',
              'extract'         => true,
              'extract_path'    => '/opt',
              'source'          => params[:real_download_url],
              'checksum_verify' => false,
              'creates'         => "/opt/smurf_exporter-#{parameters[:version]}.#{prom_os}-#{prom_arch}/smurf_exporter",
              'cleanup'         => true
            ).that_comes_before("File[/opt/smurf_exporter-#{parameters[:version]}.#{prom_os}-#{prom_arch}/smurf_exporter]")
          }

          it {
            is_expected.to contain_file("/opt/smurf_exporter-#{parameters[:version]}.#{prom_os}-#{prom_arch}/smurf_exporter").with(
              'owner' => 'root',
              'group' => 0,
              'mode'  => '0555'
            )
          }

          it {
            is_expected.to contain_file('/usr/local/bin/smurf_exporter').with(
              'ensure' => 'link',
              'target' => "/opt/smurf_exporter-#{parameters[:version]}.#{prom_os}-#{prom_arch}/smurf_exporter"
            ).that_notifies('Service[smurf_exporter]')
          }

          it {
            is_expected.to contain_user('smurf_user').with(
              'ensure' => 'present',
              'system' => true,
              'groups' => []
            )
          }

          it {
            is_expected.to contain_group('smurf_group').with(
              'ensure' => 'present',
              'system' => true
            )
          }

          # prometheus::config
          if ['debian-7-x86_64'].include?(os)
            # init_style = 'debian'

            it {
              is_expected.to contain_file('/etc/init.d/smurf_exporter').with(
                'mode'    => '0555',
                'owner'   => 'root',
                'group'   => 'root'
              ).with_content(/DAEMON_ARGS=''\n/
              ).with_content(/USER=smurf_user\n/)
            }
          elsif ['centos-6-x86_64', 'redhat-6-x86_64'].include?(os)
            # init_style = 'sysv'

            it {
              is_expected.to contain_file('/etc/init.d/smurf_exporter').with(
                'mode'    => '0555',
                'owner'   => 'root',
                'group'   => 'root'
              ).with_content(/daemon --user=smurf_user \\\n            --pidfile="\$PID_FILE" \\\n            "\$DAEMON" '' >> "\$LOG_FILE" &/)
            }
          elsif ['centos-7-x86_64', 'debian-8-x86_64', 'redhat-7-x86_64', 'ubuntu-16.04-x86_64'].include?(os)
            # init_style = 'systemd'

            it {
              is_expected.to contain_file('/etc/systemd/system/smurf_exporter.service').with(
                'mode'    => '0644',
                'owner'   => 'root',
                'group'   => 'root'
              ).that_notifies('Exec[smurf_exporter-systemd-reload]'
              ).with_content(/User=smurf_user\n/
              ).with_content(/ExecStart=\/usr\/local\/bin\/smurf_exporter\n\nExecReload=/)
            }

            it {
              is_expected.to contain_exec('smurf_exporter-systemd-reload').with(
                'command'     => 'systemctl daemon-reload',
                'path'        => ['/usr/bin', '/bin', '/usr/sbin'],
                'refreshonly' => true
              ).that_notifies('Service[smurf_exporter]')
            }
          elsif ['ubuntu-14.04-x86_64'].include?(os)
            # init_style = 'upstart'

            it {
              is_expected.to contain_file('/etc/init/smurf_exporter.conf').with(
                'mode'    => '0444',
                'owner'   => 'root',
                'group'   => 'root'
              ).with_content(/env USER=smurf_user\n/
              ).with_content(/exec start-stop-daemon -c \$USER -g \$GROUP -p \$PID_FILE -x \$DAEMON -S --\n\nend script/)
            }

            it {
              is_expected.to contain_file('/etc/init.d/smurf_exporter').with(
                'ensure' => 'link',
                'target' => '/lib/init/upstart-job',
                'owner'  => 'root',
                'group'  => 'root',
                'mode'   => '0755'
              )
            }
          else
            it {
              is_expected.to raise_error(Puppet::Error, %r{I don.t know how to create an init script for style})
            }
          end

          it {
            is_expected.to contain_service('smurf_exporter').with(
              'ensure' => 'running',
              'name'   => 'smurf_exporter',
              'enable' => true
            )
          }
        end
      end
    end
  end
end
