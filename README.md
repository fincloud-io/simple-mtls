# Setting up mTLS with your own CA
## Certificate generation

[![OpenSSL](https://img.shields.io/badge/openssl-1.1+-blue.svg)](https://www.openssl.org/index.html)


## Getting Started
This script does a number of things to provision a simple self-signed mTLS installation:
- 1 Creates a self-signed Root Certification Authority (CA) 
- 2 Creates an Intermediate Certification Authority (CA) signed by the Root CA
- 3 Creates a Server certificate, issued by the Intermediate CA

- 4 Creates client certificates from CSR files

Although a self-signed intermediateCA might be overkill, this is how the larger PKCS systems operate. Should a key get 
comprimised, or a security issue 
mTLS authentication requires certificates on both client and server in order to operate. Many small firms dont 
have a PKCS infrastructure in place, and therefore need to create self-signed certificates using their own 
Certification Authority (CA) - (also created as part of this process).

The scripts in this directory can automate the creation of the certificates.

#### Prerequisites
- [ ] gawk required for parsing ini files
- [ ] BASH version > 3.2 (see troubleshooting below, OSX requires a newer bash install than the default)
- [ ] Create a ```certificate.ini``` file from the template
- [ ] Ensure that secure passwords > 6 characters are used for both the ```ca```  and ```server``` entries


### Server Certificate generation
Once the script below has been run, a new named subdirectory will be created, with both the CA certificates and 
the Server cert / truststore.

```create_server_cert.sh```

The following two files in the named directory should be used for the gateway installation:

```myserver.pfx, truststore.jks```

## Generating a client certificate

Clients who want to connect with mTLS, will need a certificate issued and signed by our server. Clients should provide 
a Certificate Signing Request (CSR) file which should then be supplied to the script below. This will produce a client cert.

```bash 
create-client-cert.sh <csr_file>
```

Example:
```
Signature ok
   subject=C = US, ST = New York, L = New York City, O = Megacorp Client LLC, OU = IT Department, CN = megacorp.client1, emailAddress = root@megacorpclient.com
``` 

The client certificate can be found in the client subdirectory, with the name ```client.crt```.

## Troubleshooting

### I keep getting errors like this 
```declare: usage: declare [-afFirtx] [-p] [name[=value] ...]```

Upgrade your version of BASH - OSX in particular comes installed with a very old version unlikely to be upgraded.

```brew install bash``` 

Note, this doesn't replace the pre-installed version of bash, so won't affect other scripts. New bash will be installed in /usr/local/bin. 
see article [Upgrading bash on OSX](https://itnext.io/upgrading-bash-on-macos-7138bd1066ba)

Thanks to [Sleepless Beastie](https://sleeplessbeastie.eu/2019/11/11/how-to-parse-ini-configuration-file-using-bash/) for the helpful ini parsing code 

- - - - - -  
[Jon Jenkins](mailto:jj@fincloud.io) 01/08/2021
