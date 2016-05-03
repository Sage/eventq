eval $(docker-machine env)

echo setup starting.....
docker-compose rm

port_changes="no"

echo Add port forwarding rules for remote debugging
if VBoxManage controlvm default natpf1 rdbug,tcp,,1236,,1236; then
    echo port rule added
    port_changes="yes"
else
    echo IGNORE VBOX ERROR
fi
if VBoxManage controlvm default natpf1 rdebug_dispatch,tcp,,26166,,26166; then
    echo port rule added
    port_changes="yes"
else
    echo IGNORE VBOX ERROR
fi

echo Add port forwarding rules for development ssh
if VBoxManage controlvm default natpf1 rubymine_ssh,tcp,,23,,22; then
    echo port rule added
    port_changes="yes"
else
    echo IGNORE VBOX ERROR
fi

echo Add port forwarding rule for rabbitmq
if VBoxManage controlvm default natpf1 rabbitmq,tcp,,5672,,5672; then
    echo port rule added
    port_changes="yes"
else
    echo IGNORE VBOX ERROR
fi

if [ "$port_changes" == "yes" ]; then
    echo restart docker machine
    docker-machine restart
    eval $(docker-machine env)
fi

echo setup complete