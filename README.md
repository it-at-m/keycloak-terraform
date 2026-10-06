# Keycloak Terraform

[![Made with love by it@M][made-with-love-shield]][itm-opensource]

Collection of Terraform modules and example environments for configuring a Keycloak.

## Usage

### Modules

Example for the `oidc-client` module:

```terraform
module "itm-oidc-client" {
  source = "github.com/it-at-m/keycloak-tarraform/modules/oidc-client"
  ref = "main" # Version
}
```

### Example local environment

Start the provided `stack/docker-compose.yml` with `docker compose up`.

Creates an `LHM-Demo` realm with following clients and users:
- Clients
  - `lhm-demo-backend` (confidential client)
  - `lhm-demo-frontend` (public client)
- Users
  - `maria.admin` (PW: `Demo123!Admin`)
  - `thomas.tester` (PW: `Demo123!Test`)

The according Terraform configuration can be found in [`./local`](./local).

## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please open an issue with the tag "enhancement", fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".
Don't forget to give the project a star! Thanks again!

1. Open an issue with the tag "enhancement"
2. Fork the Project
3. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
4. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
5. Push to the Branch (`git push origin feature/AmazingFeature`)
6. Open a Pull Request

More about this in the [CODE_OF_CONDUCT](/CODE_OF_CONDUCT.md) file.

## License

Distributed under the MIT License. See [LICENSE][license] file for more information.

## Contact

it@M - opensource@muenchen.de
