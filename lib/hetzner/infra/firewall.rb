# frozen_string_literal: true

module Hetzner
  class Firewall
    def initialize(hetzner_client:, cluster_name:)
      @hetzner_client = hetzner_client
      @cluster_name = cluster_name
    end

    def create(high_availability:, networks:)
      @high_availability = high_availability
      @networks = networks
      puts

      if (firewall = find_firewall)
        puts 'Firewall already exists, skipping.'
        puts
        return firewall['id']
      end

      puts 'Creating firewall...'

      response = hetzner_client.post('/firewalls', create_firewall_config).body
      puts '...firewall created.'
      puts

      JSON.parse(response)['firewall']['id']
    end

    def delete(servers)
      if (firewall = find_firewall)
        puts 'Deleting firewall...'

        servers.each do |server|
          hetzner_client.post("/firewalls/#{firewall['id']}/actions/remove_from_resources",
                              remove_targets_config(server['id']))
        end

        hetzner_client.delete('/firewalls', firewall['id'])
        puts '...firewall deleted.'
      else
        puts 'Firewall no longer exists, skipping.'
      end

      puts
    end

    private

    attr_reader :hetzner_client, :cluster_name, :firewall, :high_availability, :networks

    def create_firewall_config
      rules = [
        {
          description: 'Allow port 22 (SSH)',
          direction: 'in',
          protocol: 'tcp',
          port: '22',
          source_ips: networks,
          destination_ips: []
        },
        {
          description: 'Allow all other TCP',
          direction: 'in',
          protocol: 'tcp',
          port: 'any',
          source_ips: networks,
          destination_ips: []
        },
        {
          description: 'Allow ICMP (ping)',
          direction: 'in',
          protocol: 'icmp',
          port: nil,
          source_ips: [
            '0.0.0.0/0',
            '::/0'
          ],
          destination_ips: []
        },
        {
          description: 'Allow all TCP traffic between nodes on the private network',
          direction: 'in',
          protocol: 'tcp',
          port: 'any',
          source_ips: [
            '10.0.0.0/16'
          ],
          destination_ips: []
        },
        {
          description: 'Allow all UDP traffic between nodes on the private network',
          direction: 'in',
          protocol: 'udp',
          port: 'any',
          source_ips: [
            '10.0.0.0/16'
          ],
          destination_ips: []
        }
      ]

      unless high_availability
        rules << {
          description: 'Allow port 6443 (Kubernetes API server)',
          direction: 'in',
          protocol: 'tcp',
          port: '6443',
          source_ips: [
            '0.0.0.0/0',
            '::/0'
          ],
          destination_ips: []
        }
      end

      {
        name: cluster_name,
        rules:
      }
    end

    def remove_targets_config(server_id)
      {
        remove_from: [
          {
            server: {
              id: server_id
            },
            type: 'server'
          }
        ]
      }
    end

    def find_firewall
      hetzner_client.get('/firewalls')['firewalls'].detect { |firewall| firewall['name'] == cluster_name }
    end
  end
end
