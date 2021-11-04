#!/bin/bash
rm -f ./objects.yaml ./passwd.txt
start_username=1
read -p "How many users you want to add?: " amount_users
if [[ $amount_users =~ ^[0-9]+$ ]]; then
    echo "You entered $amount_users"
else
    echo "You entered $amount_users, which is not a number"
    exit 1
fi
# obtain current htpasswd-secret file
oc get secret htpasswd-secret -ojsonpath={.data.htpasswd} -n openshift-config | base64 --decode > current.htpasswd
# obtain the last username in it
last_line=$(tail -n 1 current.htpasswd)
# obtain the username and it's number
username=$(echo $last_line | cut -d ":" -f 1)
last_username=${username#user}
if [[ $last_username =~ ^[0-9]+$ ]]; then
    start_username=$((last_username+1))
else
    start_username=1
fi
# calculate the end_username
end_username=$((start_username+amount_users-1))
# loop the users to generate the yaml file and passwd file
for i in $(seq $start_username $end_username)
do
    if [ $i -eq $start_username ]
    then
        randompass=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
        htpasswd -b -c -B ./passwd user$i $randompass
        echo "user$i:$randompass" >> ./passwd.txt
    else
    randompass=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
        htpasswd -b -B ./passwd user$i $randompass
    fi   
    echo "user$i:$randompass" >> ./passwd.txt
    cp ./template.yaml ./template.user$i.yaml
    sed -i "s/_USERNAME_/user$i/g" ./template.user$i.yaml
done
# append the new users to the current htpasswd file
cat ./passwd >> ./current.htpasswd
# unify the templates in one yaml file
for file in ./template.user*.yaml
do
    cat $file >> ./objects.yaml
    echo -e "\n---" >> ./objects.yaml
    rm -f $file
done
# optional to add htpasswd-secret to the objets.yaml template
read -p "Do you want to enable the users? (y/n): " enable
if [ $enable == "y" ]
then
    oc create secret generic htpasswd-secret --from-file=htpasswd=./current.htpasswd -n openshift-config --dry-run=client -o yaml >> ./objects.yaml
fi
echo "The passwd.txt file content:"
cat ./passwd.txt
# run it manually to import objects from objects.yaml file
echo "Run the next command to proceed:"
echo "oc apply -f ./objects.yaml"

