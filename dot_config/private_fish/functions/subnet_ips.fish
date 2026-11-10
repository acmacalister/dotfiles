function subnet_ips
    set -l subnets subnet-0db744339b9eecc8d subnet-048608e9244e97e94 subnet-013bd0ea51c1d801e subnet-0d89b9803e3f9a9f3 subnet-09ccf42d2e6c60b13
    set -l total 0

    for subnet in $subnets
        set -l count (aws ec2 describe-subnets --subnet-ids $subnet --query 'Subnets[*].[AvailableIpAddressCount]' --output text)
        echo "Subnet $subnet: $count available IPs"
        set total (math $total + $count)
    end

    echo "Total available IPs: $total"
end
