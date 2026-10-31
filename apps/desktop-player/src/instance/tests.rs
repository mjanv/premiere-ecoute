use super::*;

#[test]
fn only_error_already_exists_means_another_instance() {
    assert!(is_taken(183));
    assert!(!is_taken(0));
    assert!(!is_taken(5));
}

#[test]
fn the_second_claim_of_a_name_is_refused() {
    let name = format!("Local\\pep-test-{}", std::process::id());
    assert!(claim(&name));
    assert!(!claim(&name));
}

#[test]
fn different_names_do_not_collide() {
    let id = std::process::id();
    assert!(claim(&format!("Local\\pep-test-a-{id}")));
    assert!(claim(&format!("Local\\pep-test-b-{id}")));
}
