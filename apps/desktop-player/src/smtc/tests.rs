use super::*;

#[test]
fn a_refused_command_is_an_error() {
    assert_eq!(accepted(true), Ok(()));
    assert!(accepted(false).is_err());
}
